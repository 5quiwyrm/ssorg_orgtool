# Guide
## Day system
Dates are stored as days since epoch (1 Jan 1970). Setdate comes before duedate, and they represent the difference with the current date (positive means future, negative means past).

## Keybinds
The keybinds for ssorg are very simple, they are:
- No args for basic print
- b for brief
- a for all
- s for show, ucpa corrispond to uncompleted, completed, inprogress and aborted
- f for filter, this is for seeing ASAP tasks
- t to add new task
- m to make a task's status a certain way:
  - mu for make uncomplete
  - mc for make complete
  - mp for make inprogress
  - ma for make aborted
- d to delete a task and all subtasks

## Indexing system
You can specify the target of a command by using numbers and symbols, for example:
```
1: +0   | +0   | Uncompleted | NoTag | say hi | [U: 1, C: 0, P: 0, A: 0]
  0: +0   | +0   | Uncompleted | NoTag | say h | [U: 0, C: 0, P: 0, A: 0]
  1: +0   | +0   | Uncompleted | NoTag | say i | [U: 0, C: 0, P: 0, A: 0]
```
`ssorg mc 10` completes the task "say h", whereas `ssorg d 11` deletes the task "say i"
