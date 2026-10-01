class_name KinuPart
extends Resource
## One piece of My Kinu's look, worn in a single equipment slot. Visual only: parts are drawn
## over the Kinu and never change its hitbox, mass or stacking.

@export var id: String = ""
## "body", "hat", "arms" or "glasses".
@export var slot: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Cost in soybeans in the Kinu Shop's Parts tab. 0 with no other source means a free starter.
@export var price: int = 0
## Which procedural design KinuModel builds for this part.
@export var style: String = ""
@export var color: Color = Color.WHITE
@export var accent: Color = Color.WHITE
## Earned in the Kinu Book instead of bought; same goal names as KinuOutfit.goal.
@export var goal: String = ""
@export var goal_amount: int = 0
## Only ever won in the Kinu Catcher.
@export var crane_only: bool = false
## A My Kinu level reward: granted on reaching this level, never sold or dropped by the Catcher.
@export var level: int = 0
## Owned by everyone from the moment its slot unlocks.
@export var starter: bool = false
@export var available: bool = true
## "common", "rare", "epic" or "legendary" for shop and Kinu Catcher parts; empty otherwise.
@export var rarity: String = ""
## Parts share the outfit source fields so ownership and Catcher code can treat them alike.
var showcase: String = ""
var event: String = ""
var finish: KinuFlavour = null
