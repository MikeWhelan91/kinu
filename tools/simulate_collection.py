#!/usr/bin/env python3
"""Monte Carlo estimate of how long a player takes to complete the whole cosmetic collection.

Models one day at a time for three player profiles: runs (beans, Kinu landed, My Kinu XP), daily
missions, the seven-day calendar, the weekly challenge, Kinu Claw plays (two free a day plus
tickets, with the real odds, pity and pool), shop purchases (cheapest unowned item first), My Kinu
level rewards, and Kinu Book goals for outfits, decor and parts. Reads prices, sources and goals
from resources/kinu/catalog.tres and scripts/kinu/kinu_parts.gd, so it follows catalogue changes.

    python3 tools/simulate_collection.py [--trials 400] [--seed 7]
"""

import argparse
import random
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "resources/kinu/catalog.tres"
PARTS = ROOT / "scripts/kinu/kinu_parts.gd"

# Kinu Claw (scripts/systems/kinu_catcher.gd)
COSMETIC = 0.10
TICKET_SHARE = 0.09
JACKPOT = (15000, 0.0003)
BEAN_PRIZES = [(50, 40), (100, 30), (200, 16), (400, 8), (1000, 3)]
TICKET_PRIZES = [(1, 62), (2, 27), (3, 11)]
TIER_WEIGHTS = {"common": 55, "rare": 25, "epic": 13, "legendary": 7}
PITY = 15
FREE_PLAYS = 2
# Daily calendar (scripts/systems/daily_calendar.gd): beans and tickets by day, day 7 = Claw item.
CALENDAR = [("beans", 150), ("beans", 200), ("tickets", 1), ("beans", 250), ("beans", 300), ("tickets", 2), ("item", 1)]
WEEKLY_BEANS, WEEKLY_TICKETS = 750, 1
PART_PRICES = {"common": [600, 700, 800], "rare": [1150, 1300, 1400], "epic": [1700, 1900, 2000]}
LEVEL_PART_EVERY, SPARE_TICKETS = 5, 1
# NestRun.RUN_BEAN_SCALE: base run payouts are scaled; Lucky catches are not.
RUN_BEAN_SCALE = 0.7

# Player profiles. pile/placed are a typical run, best is where their best pile settles, and
# missions is how many of the three daily missions they finish (one of the three pays a ticket).
PROFILES = {
    "casual": {"runs": 3, "pile": 18, "placed": 22, "best": 32, "missions": 2, "weekly": .5, "minutes": 3.0},
    "regular": {"runs": 6, "pile": 28, "placed": 33, "best": 45, "missions": 2.6, "weekly": .9, "minutes": 3.5},
    "dedicated": {"runs": 12, "pile": 38, "placed": 44, "best": 60, "missions": 3, "weekly": 1.0, "minutes": 4.0},
}
MISSION_REWARDS = [150, 225, 310]


def read_catalog():
    """Every collectable as a dict: key, kind, source, rarity, price, goal, amount."""
    items = []
    text = CATALOG.read_text()
    for kind_id, body in re.findall(r'\[sub_resource type="Resource" id="((?:outfit|box|room)_[^"]+)"\]\n(.*?)(?=\n\[|\Z)', text, re.S):
        attrs = dict(re.findall(r'^(\w+) = (.*)$', body, re.M))
        get = lambda key, default='""': attrs.get(key, default).strip('"')
        if get("available", "true") == "false" or get("finish", "") not in ("", "null"):
            pass
        kind = kind_id.split("_", 1)[0]
        price = int(attrs.get("price", "0"))
        if get("event") or get("showcase"):
            source = "special"
        elif attrs.get("crane_only") == "true":
            source = "claw"
        elif get("goal"):
            source = "goal"
        elif price <= 0:
            continue  # free starter decor or no-outfit
        else:
            source = "shop"
        items.append({"key": f"{kind}:{get('id')}", "kind": kind, "source": source, "rarity": get("rarity"),
                      "price": price, "goal": get("goal"), "amount": int(attrs.get("goal_amount", "0"))})
    for pid, source, extra in re.findall(r'\["([a-z0-9_]+)", "(?:body|hat|arms|glasses)", "[^"]+", "[a-z_]+", "[0-9a-f]+", "[0-9a-f]+", "([a-z:]+)", (-?\d+)\]', PARTS.read_text()):
        extra = int(extra)
        item = {"key": f"part:{pid}", "kind": "part", "rarity": "", "price": 0, "goal": "", "amount": 0}
        if source == "starter":
            continue
        if source == "level":
            item.update(source="level", amount=extra)
        elif source.startswith("crane:"):
            item.update(source="claw", rarity=source.split(":")[1])
        elif source in PART_PRICES:
            item.update(source="shop", rarity=source, price=PART_PRICES[source][max(0, min(extra, 2))])
        else:
            item.update(source="goal", goal=source, amount=extra)
        items.append(item)
    return items


def xp_to_next(level):
    return 60 + 20 * (level - 1)


def level_for(xp):
    level = 1
    while xp >= xp_to_next(level):
        xp -= xp_to_next(level)
        level += 1
    return level


def beans_for_run(score):
    return round((score * 5 + score // 10 * 10) * RUN_BEAN_SCALE)


def stat_value(goal, stats, profile):
    """Lifetime stat for a Kinu Book goal. Unmodelled goals are approximated from runs."""
    return {
        "best": stats["best"], "total": stats["total"], "runs": stats["runs"],
        "flavours": min(22, 6 + stats["best"] // 3), "clean": int(stats["best"] * .75),
        "streak": int(stats["best"] * .9), "lucky": stats["lucky"], "height": int(stats["best"] * 11 * 2.3),
        "missions": stats["missions"], "days": stats["days"], "glazed": stats["glazed"],
    }.get(goal, 0)


def skill_gated(items, profile):
    """Goal items this profile can never reach however long it plays: they need a bigger pile,
    cleaner run, longer streak or taller tower than its best allows."""
    ceiling = {"best": profile["best"], "total": 10**9, "runs": 10**9, "lucky": 10**9, "missions": 10**9, "days": 10**9, "glazed": 10**9}
    return [i for i in items if i["source"] == "goal" and stat_value(i["goal"], ceiling, profile) < i["amount"]]


def simulate(items, profile, rng, max_days=3000):
    owned = set()
    claw_pool = [i for i in items if i["source"] in ("claw", "shop") and i["kind"] in ("outfit", "box", "room", "part") and i["rarity"] in TIER_WEIGHTS]
    claw_only = [i for i in items if i["source"] == "claw"]
    shop = sorted([i for i in items if i["source"] == "shop"], key=lambda i: i["price"])
    goals = [i for i in items if i["source"] == "goal"]
    level_parts = sorted([i for i in items if i["source"] == "level"], key=lambda i: i["amount"])
    gated = {i["key"] for i in skill_gated(items, profile)}
    target = [i for i in items if i["source"] != "special" and i["key"] not in gated]
    beans = tickets = xp = since_item = 0
    stats = {"best": 0, "total": 0, "runs": 0, "lucky": 0, "missions": 0, "days": 0, "glazed": 0}
    done = {}

    def mark(group, day):
        if group not in done:
            done[group] = day

    def claw_play():
        nonlocal beans, tickets, since_item
        left = [i for i in claw_pool if i["key"] not in owned]
        roll = rng.random()
        if left and (since_item >= PITY - 1 or roll < COSMETIC):
            tiers = {}
            for item in left:
                tiers.setdefault(item["rarity"], []).append(item)
            names = list(tiers)
            tier = rng.choices(names, weights=[TIER_WEIGHTS[n] for n in names])[0]
            owned.add(rng.choice(tiers[tier])["key"])
            since_item = 0
            return
        since_item += 1
        if roll < (COSMETIC if left else 0) + TICKET_SHARE:
            tickets += rng.choices([a for a, _ in TICKET_PRIZES], weights=[w for _, w in TICKET_PRIZES])[0]
        elif rng.random() < JACKPOT[1]:
            beans += JACKPOT[0]
        else:
            beans += rng.choices([a for a, _ in BEAN_PRIZES], weights=[w for _, w in BEAN_PRIZES])[0]

    for day in range(1, max_days + 1):
        stats["days"] = day
        # Runs: best pile climbs towards the profile's ceiling over the first few weeks.
        stats["best"] = min(profile["best"], max(stats["best"], int(profile["best"] * min(1.0, .45 + day / 40))))
        level_before = level_for(xp)
        for _ in range(profile["runs"]):
            pile = max(3, int(rng.gauss(profile["pile"], profile["pile"] * .3)))
            placed = pile + rng.randint(0, 6)
            beans += beans_for_run(pile) + (50 if rng.random() < .45 else 0)
            stats["total"] += placed
            stats["runs"] += 1
            stats["lucky"] += 1 if rng.random() < .45 else 0
            stats["glazed"] += rng.randint(0, 2)
            xp += placed + (10 if placed >= 5 else 0)
        # My Kinu level rewards.
        for reached in range(level_before + 1, level_for(xp) + 1):
            beans += min(100 + 10 * reached, 400)
            if reached % LEVEL_PART_EVERY == 0:
                part = next((p for p in level_parts if p["amount"] == reached), None)
                if part:
                    owned.add(part["key"])
                else:
                    tickets += SPARE_TICKETS
        # Missions, calendar, weekly.
        finished = profile["missions"]
        whole = int(finished)
        beans += sum(MISSION_REWARDS[:whole]) + (MISSION_REWARDS[whole] * (finished - whole) if whole < 3 else 0)
        stats["missions"] += round(finished)
        tickets += 1 if finished >= 2 else 0
        kind, amount = CALENDAR[(day - 1) % 7]
        if kind == "beans":
            beans += amount
        elif kind == "tickets":
            tickets += amount
        else:
            left = [i for i in claw_only if i["key"] not in owned]
            if left:
                owned.add(rng.choice(left)["key"])
            else:
                tickets += 3
        if day % 7 == 0 and rng.random() < profile["weekly"]:
            beans += WEEKLY_BEANS
            tickets += WEEKLY_TICKETS
        # Kinu Claw: the free plays, then every ticket.
        for _ in range(FREE_PLAYS):
            claw_play()
        while tickets > 0:
            tickets -= 1
            claw_play()
        # Kinu Book goals.
        for item in goals:
            if item["key"] not in owned and stat_value(item["goal"], stats, profile) >= item["amount"]:
                owned.add(item["key"])
        # Shop: buy the cheapest unowned item while beans allow.
        for item in shop:
            if item["key"] in owned:
                continue
            if beans < item["price"]:
                break
            beans -= item["price"]
            owned.add(item["key"])
        for group, members in (("parts", [i for i in target if i["kind"] == "part"]),
                               ("shop", shop),
                               ("outfits+decor", [i for i in target if i["kind"] != "part"]),
                               ("claw-only", claw_only), ("level parts", level_parts),
                               ("everything", target)):
            if all(i["key"] in owned for i in members):
                mark(group, day)
        if "everything" in done:
            break
    done["level"] = level_for(xp)
    return done


def percentile(values, p):
    values = sorted(values)
    return values[round((len(values) - 1) * p)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--trials", type=int, default=300)
    parser.add_argument("--seed", type=int, default=7)
    args = parser.parse_args()
    items = read_catalog()
    counts = {}
    for item in items:
        counts[(item["kind"] == "part", item["source"])] = counts.get((item["kind"] == "part", item["source"]), 0) + 1
    shop_total = sum(i["price"] for i in items if i["source"] == "shop")
    part_shop = sum(i["price"] for i in items if i["source"] == "shop" and i["kind"] == "part")
    print("Catalogue:", ", ".join(f"{'parts' if k[0] else 'outfits/decor'} {k[1]}={v}" for k, v in sorted(counts.items())))
    print(f"Shop sink: {shop_total:,} beans in total, of which parts {part_shop:,}")
    print("Level 50 (last level part) needs", sum(xp_to_next(l) for l in range(1, 50)), "XP")
    for name, profile in PROFILES.items():
        rng = random.Random(args.seed)
        results = [simulate(items, profile, rng) for _ in range(args.trials)]
        print(f"\n{name}: {profile['runs']} runs a day (~{profile['runs'] * profile['minutes']:.0f} min), typical pile {profile['pile']}")
        gated = skill_gated(items, profile)
        print(f"  skill-gated, never reached at a best pile of {profile['best']}: " + (", ".join(f"{i['key']} ({i['goal']} {i['amount']})" for i in gated) or "none"))
        for group in ("claw-only", "shop", "parts", "outfits+decor", "level parts", "everything"):
            values = [r.get(group, 3000) for r in results]
            capped = sum(1 for v in values if v >= 3000)
            note = f" ({capped} of {len(values)} not done in 3000 days)" if capped else ""
            print(f"  {group:14} median {percentile(values, .5):5} days  (p10 {percentile(values, .1)}, p90 {percentile(values, .9)}){note}")


if __name__ == "__main__":
    main()
