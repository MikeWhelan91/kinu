# Costume review

The original outfit builder put a cap and back panel on nearly every Kinu. The new collection uses complete fabric suits, clothing separates, a draped sheet, or a small accessory as appropriate. Shape IDs, outfit IDs, prices, ownership and physics hitboxes remain compatible.

| Outfit | Review and change |
| --- | --- |
| Little leaf | Suits a small accessory. Retained the uncovered Kinu and gave the leaf a clearer shape. |
| Frog | Complete green suit, cream face opening and belly, raised frog eyes and webbed toes. |
| Bunny | Complete pink suit, inset ears, belly, paws and a cotton tail. |
| Fox | Complete orange suit, contrasting ear interiors and a cream-tipped tail. |
| Tanuki | Brown suit, rounded ears, side markings, belly, ringed tail and leaf. |
| Bat | Purple suit with pointed ears and scalloped membrane wings with fingers. |
| Strawberry | Red costume with seeds across the body, a leafy crown and stem. |
| Panda | White suit, black ears and paws. Patches use the same anchors as Kinu's animated eyes, with contrasting eyes drawn above the fabric. Removed the misplaced duplicate eye markings. |
| Ghost | Continuous draped sheet with a flared, rippled hem. Covers the original body and face; spooky eye holes and a mouth replace the normal expression. |
| Ninja | Dark suit, exposed eye slot, covered mouth, wrapped tunic, red sash and tied fabric tails. |
| Dino | Green suit, belly, a tapered tail and contrasting dorsal spikes. |
| Tiger | Rounded ears, stripes across the suit, belly and ringed tail. |
| Pirate | Red tied bandana, a single eyepatch with strap, gold hoop, striped shirt and dark vest. The patched eye is omitted from every expression. |
| Dragon | Green suit, cream horns, membrane wings, contrasting crest and tapered tail. |
| Shark | Gray suit, belly, dorsal and side fins, tail fins and teeth framing the face opening. |
| Astronaut | Suit with a contrasting visor rim, ear seals, chest controls and life-support tanks. |

## Rendering and verification

- Costume meshes have a separate opaque fabric material, so glass/jelly finishes cannot make the ghost sheet or eyepatch transparent.
- Outfit style participates in the face cache and remains attached to the model during runtime mood changes.
- The shop now says **Outfits** and **No outfit**.
- `tests/costumes.gd` exercises 16 outfits × 5 shapes × 6 moods, face-cache isolation, all special finishes, and costume-cache cleanup.
- `tools/costume_sheet.tscn` renders the complete collection. `-- --page=0` through `-- --page=4` select Block, Slab, Long, Tall and Ball. Pages after Block cycle through the six moods.

Run from the project root with the Godot executable:

```sh
godot --headless --path . --script tests/costumes.gd
godot --path . tools/costume_sheet.tscn -- --page=0
godot --headless --path . tests/integration.tscn
```

Validation result: all 480 costume combinations and 447 existing integration checks passed. The headless integration run emitted resource-leak warnings during engine shutdown; the costume-specific test exited cleanly.

## Flavour and finish compatibility

Exposed faces on animal suits, Strawberry, Ninja and Astronaut now inherit the selected flavour colour, visible pattern and finish material. Expressions retain pale ink on dark flavours such as Galaxy. Small texture marks stay within the opening and clear of the eyes; hoods cover Sakura's top blossom. Ninja exposes only the eye slot.

Little leaf and Pirate retain their visible original tofu body. Panda and Ghost fully cover Kinu and keep their costume face and colours. Belly panels, ears, tails, fabric, masks and equipment keep their own colours. Transparent finishes reveal fabric beneath exposed skin; they do not make clothing transparent.

The costume test also checks all 1,440 shape/outfit/flavour-or-finish combinations for colour, material assignment and expression contrast. Add `--flavours` to the sheet renderer for mixed examples (including Galaxy, Crystal, Jelly and Gold).

### Ghost underside

The sheet now closes underneath along the exact wavy hem, with a recessed fabric centre. Verified upright, tilted and from below on all five shapes in `docs/ghost-underside.png`. The costume test casts nine rays from below per shape to check underside coverage and outward triangle winding.
