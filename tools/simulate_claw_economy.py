#!/usr/bin/env python3
"""Monte Carlo estimate of Kinu Claw collection times from the current catalog."""

import argparse
import random
import re
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "resources/kinu/catalog.tres"
PARTS = ROOT / "scripts/kinu/kinu_parts.gd"
# Matches KinuCatcher.COSMETIC_ODDS; tickets keep their own fixed slice of every other play.
COSMETIC = 0.15
TICKET_SLICE = 0.09
TIERS = ("common", "rare", "epic", "legendary")
WEIGHTS = (55, 25, 13, 7)


def catalog_counts():
    source = CATALOG.read_text()
    counts = {tier: [0, 0] for tier in TIERS}  # paid, claw-only
    for match in re.finditer(
        r'\[sub_resource type="Resource" id="(?:outfit|box|room)_[^"]+"\]\n'
        r'(.*?)(?=\n\[sub_resource|\n\[resource\])',
        source,
        re.S,
    ):
        attrs = dict(re.findall(r'^(\w+) = (.*)$', match.group(1), re.M))
        if attrs.get("available") == "false" or any(
            attrs.get(key, '""') != '""' for key in ("goal", "showcase", "event")
        ):
            continue
        claw = attrs.get("crane_only") == "true"
        price = int(attrs.get("price", "0"))
        if not claw and price <= 0:
            continue
        tier = attrs["rarity"].strip('"')
        counts[tier][int(claw)] += 1
    # My Kinu parts sold in the shop or only won in the Catcher.
    for source in re.findall(r'"[0-9a-f]{6}", "[0-9a-f]{6}", "([a-z:]+)", -?\d+\]', PARTS.read_text()):
        if source in ("common", "rare", "epic"):
            counts[source][0] += 1
        elif source.startswith("crane:"):
            counts[source.split(":", 1)[1]][1] += 1
    return counts


def percentile(values, p):
    values = sorted(values)
    return values[round((len(values) - 1) * p)]


def weighted_tier(rng, counts, claw_only=False):
    active = [i for i, pair in enumerate(counts) if pair[1]] if claw_only else [
        i for i, pair in enumerate(counts) if sum(pair)
    ]
    return rng.choices(active, weights=[WEIGHTS[i] for i in active])[0]


def run_player(rng, base, weekly=True, shop_paid=False, daily_free_plays=1,
               pity_every=15, max_days=5000):
    remaining = [[0, claw] if shop_paid else [paid, claw] for paid, claw in base]
    target_claw = sum(pair[1] for pair in remaining)
    target_all = sum(map(sum, remaining))
    tickets = 0
    since_item = 0
    plays = 0
    claw_day = None
    all_day = None
    for day in range(1, max_days + 1):
        # Claim the seven-day attendance prize. Day 7 selects an unowned claw-only item.
        streak_day = (day - 1) % 7 + 1
        if streak_day == 3:
            tickets += 1
        elif streak_day == 6:
            tickets += 2
        elif streak_day == 7:
            if any(pair[1] for pair in remaining):
                tier = weighted_tier(rng, remaining, claw_only=True)
                remaining[tier][1] -= 1
            else:
                tickets += 3
        if weekly and streak_day == 7:
            tickets += 1

        # Free daily play plus every earned ticket; ticket prizes can add more plays.
        free = daily_free_plays
        while free or tickets:
            if free:
                free -= 1
            else:
                tickets -= 1
            plays += 1
            roll = rng.random()
            if sum(map(sum, remaining)) and (since_item >= pity_every - 1 or roll < COSMETIC):
                tier = weighted_tier(rng, remaining)
                paid, claw = remaining[tier]
                chosen = rng.randrange(paid + claw)
                remaining[tier][int(chosen >= paid)] -= 1
                since_item = 0
            else:
                since_item += 1
                if roll < (COSMETIC + TICKET_SLICE if sum(map(sum, remaining)) else TICKET_SLICE):
                    tickets += rng.choices((1, 2, 3), weights=(62, 27, 11))[0]

        if claw_day is None and not any(pair[1] for pair in remaining):
            claw_day = day
        if not any(sum(pair) for pair in remaining):
            all_day = day
            break
    return claw_day, all_day, plays


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--trials", type=int, default=10000)
    parser.add_argument("--seed", type=int, default=20260930)
    args = parser.parse_args()
    base = list(catalog_counts().values())
    print("Catalog paid/claw by tier:", catalog_counts())
    for label, weekly, shop, daily_free, pity in (
        ("previous: 1 daily play, pity 15; no shop", True, False, 1, 15),
        ("1 daily play, pity 20; no shop", True, False, 1, 20),
        ("previous: 2 daily plays, pity 15; no shop", True, False, 2, 15),
        ("current: 2 daily plays, pity 10; no shop", True, False, 2, 10),
        ("2 daily plays, pity 20; no shop", True, False, 2, 20),
        ("3 daily plays, pity 20; no shop", True, False, 3, 20),
        ("shop all paid items upfront: 1 daily play, pity 15", True, True, 1, 15),
        ("shop all paid items upfront: 2 daily plays, pity 20", True, True, 2, 20),
    ):
        rng = random.Random(args.seed)
        results = [run_player(rng, base, weekly, shop, daily_free, pity) for _ in range(args.trials)]
        print(label)
        for name, index in (("claw-only", 0), ("machine pool", 1)):
            values = [row[index] for row in results]
            print(f"  {name}: p10={percentile(values, .1)} median={percentile(values, .5)} "
                  f"p90={percentile(values, .9)} mean={sum(values)/len(values):.1f} days")
        print(f"  mean plays through completion: {sum(row[2] for row in results)/len(results):.1f}")


if __name__ == "__main__":
    main()
