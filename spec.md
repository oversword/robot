The robot will be in the stopped state by default
Picking up a running robot will give you a stopped robot
Picking up an erroring robot will give you a stopped robot
Picking up a broken robot will give you a broken robot
When a robot is picked up it will drop the fuel inventory contents
When a robot is picked up it will drop the main inventory contents
When a robot is picked up it will keep its abilities inventory contents
When a robot is picked up it will keep its code contents
When a robot is picked up it will keep its memory contents
When a robot is picked up it will keep its ignore_errors state
When a robot is placed down it will have an empty fuel inventory
When a robot is placed down it will have an empty main inventory
When a robot is placed down it will restore its abilities inventory contents
When a robot is placed down it will restore its code contents
When a robot is placed down it will restore its memory contents
When a robot is placed down it will restore its ignore_errors state

The fuel item will appear behind the top left item slot of the fuel inventory

The robot has 3 inventories: fuel, main (storage) and abilities
Only fuel can be put in the fuel inventory
Only ability items can be placed in the abilities inventory
Only one of each ability item can be placed in the abilities inventory
Anything can be put in the main inventory
These rules must be maintained when moving items between inventories
The main inventory will have one slot by default
The fuel inventory will have one slot by default
The abilities inventory will have 5 slots
The abilities index will list all abilities

"Edit program" will open  the program editing formspec
"Save program" will store the current code
"Save program" will set the status to "stopped" if the status is "error"
"Save program" will clear the current error message if the status is "error"
"Save program" will return the player to the inventory formspec
"Reset memory" will completely clear the internal memory of the robot
"Reset memory" will not return the player to the inventory formspec
"Ignore errors" will change the status of the ignore_errors flag
"Ignore errors" will not return the player to the inventory formspec

Clicking "Run" when the robot is stopped will set the state to "running"
Clicking "Run" when the robot is stopped start the node timer

Right clicking the robot when it is running will set the state to "stopped"
Right clicking the robot will open the inventory formspec

Clicking "ERROR" when the robot is erroring will open a formspec displaying the error message
Clicking "Dismiss error" will return the player to the inventory formspec
Clicking "Dismiss error" when the robot is erroring will clear the error message
Clicking "Dismiss error" when the robot is erroring will set the status to "stopped"

An ability function can be called when the ability is not enabled
If an ability is called when it is not enabled it will produce an error


Turn:
Calling robot.turn() will rotate the robot clockwise (from the top)
Calling robot.turn(false) will rotate the robot clockwise (from the top)
Calling robot.turn(true) will rotate the robot anticlockwise (from the top)

Move:
Calling robot.move() will move the robot one block forwards
Calling robot.move() behind a space that is not protected by the owner of the robot will thrown an error
Calling robot.move() with the push ability behind a block will thron an error
The move action will return the new position of the robot



If the robot falls from a height greater than 10 blocks it will enter the broken state
If the robot is punched with the repair item it will enter the stopped state
