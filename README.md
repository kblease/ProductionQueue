# ProductionQueue
### Add production queuing to Civ VI!

![Civ VI Production Queue Screenshot](http://i.imgur.com/ieaQ0iY.jpg)

Installation
============
* Download the mod and extract the contents to the Civilization VI Mods folder.  
    * Windows - C:\Users\USERNAME\Documents\My Games\Sid Meier's Civilization VI\Mods  
    * OSX - /Users/USERNAME/Library/Application Support/Sid Meier's Civilization VI/Mods  
    * Linux - /home/USERNAME/.local/share/aspyr-media/Sid Meier's Civilization VI/Mods  
* Enable the mod in the Additional Content section of the main menu.

Controls
========
Actions when clicking an item in the "Choose Production" panel:
* Left-Click: Add the item to the bottom of the queue.
* Control+Left-Click or Middle-Click: Add the item to the top of the queue.

Actions when click an item in the "Production Queue" panel:
* Left-Click and drag to new position: Move the item to the position when the mouse button is released. i.e. Drag and drop.
* Double Left-Click or Middle-Click: Move the item to the top of the queue.
* Left-Click and drag off queue: Remove the item from the queue.
* Hover: Reveal reserved plot of placed item (district or wonder) on the map.

Instructions
============
When you first load a new game with the mod enabled, the production queue panel will be visible by default to the left of a city's production menu. The panel can be collapsed by clicking the small tab on the upper-left. Using the controls listed in the section below, you can add/remove and manipulate production items in a per-city queue.

All types of production items are eligible to be added to the queue. This includes districts and wonders! When adding a district or wonder to the queue, you will choose a plot for it like normal. However, the actual placing of the plot will not occur until the item is in the top position of the queue. At that time, it will automatically place the item on the plot that was selected upon adding it to the queue. Anytime before it reaches the top of the queue, you are free to remove it from the queue and re-place it. But remember, as soon as it reaches the top of the queue, it will be placed and be permanent (as occurs when placing a district or wonder in the base game).

Districts and buildings that are prerequisites for other production items that are already researched (techs and civics) will unlock the next one. For example, you can queue a Commercial Hub and then immediately queue a Market if the required techs are researched. Continuing with this same example, the Market added below the Commercial Hub would be incapable of being moved ahead of it. In other words, the required order of the queue will be maintained. If you attempt to reorder an item in a way that would be impossible, it will move as far as it can before stopping. If you attempt to remove an item which is depended upon by other items below it, the removal will cascade and remove all items within the same dependency chain. In our previous example, this would mean that removing the Commercial Hub would also result in the Market being removed.

Units in a city's queue which become obsolete will be automatically switched to the unit that is replacing it. In the event the unit that replaces the now obsolete unit is ineligible for production, the units will be removed from your queue. For example: Your queued Warriors are forced to become obsolete upon learning the Gunpowder tech, but the unit which replaces them is the Swordsman which requires Iron. If you do not have Iron, the Warriors will be removed from the queue rather than being upgraded to Swordsmen. 

Altered Game Assets
-------------------
In case you are curious up front which game assets have been modified, here is a list:
* UI\Panels\ProductionPanel.lua
* UI\ProductionPanel.xml
* UI\StrategicView_MapPlacement.lua
* UI\SupportFunctions.lua

Copyright 2018 Kevin Blease. This item is not authorized for posting on Steam, except under the Steam account named kevin@thefixed.com.
