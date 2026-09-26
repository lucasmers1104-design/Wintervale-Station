## Zentrale Maße und Bauregeln des Gleissystems.
##
## Alle Werte in Metern bzw. Grad. Änderungen hier wirken sich auf Planung,
## Prüfung und Modelle gleichermaßen aus.
class_name RailConfig
extends RefCounted

# --- Querschnitt (Höhen relativ zur Gleisachse = Geländehöhe) ---------------
## Oberkante des Schotterbetts.
const BALLAST_TOP := 0.32
const SLEEPER_HEIGHT := 0.14
## Unterkante der Schienen (= Oberkante der Schwellen).
const RAIL_BASE := BALLAST_TOP + SLEEPER_HEIGHT
const RAIL_HEIGHT := 0.15
## Abstand der Schienenmitte von der Gleisachse.
const RAIL_OFFSET := 0.75
const SLEEPER_SPACING := 0.7
const SLEEPER_SIZE := Vector3(2.5, SLEEPER_HEIGHT, 0.26)

# --- Bauregeln ---------------------------------------------------------------
const MIN_LENGTH := 3.0
const MAX_LENGTH := 60.0
## Kleinster erlaubter Kurvenradius.
const MIN_RADIUS := 12.0
## Maximale Richtungsänderung innerhalb eines Gleisstücks.
const MAX_TURN_DEGREES := 90.0
## Maximale Steigung (0.05 = 5 %).
const MAX_GRADE := 0.05
## So weit darf das Gelände über / unter der Gleisachse liegen.
const MAX_TERRAIN_ABOVE := 0.35
const MAX_TERRAIN_BELOW := 0.6
## Mindestabstand zweier Gleisachsen (parallele Gleise).
const MIN_TRACK_DISTANCE := 3.9
## Halbe Breite des Lichtraums, der frei von Objekten sein muss.
const CLEARANCE_HALF_WIDTH := 1.4

# --- Bedienung ---------------------------------------------------------------
## Radius, in dem der Cursor an offene Gleisenden einrastet.
const SNAP_RADIUS := 3.0
## Freie gerade Gleise rasten in diesen Winkelschritten ein (Alt = frei).
const ANGLE_SNAP_DEGREES := 15.0
