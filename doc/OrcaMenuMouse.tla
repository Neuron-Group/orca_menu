----------------------------- MODULE OrcaMenuMouse -----------------------------
EXTENDS Naturals, Sequences, TLC

\* Extended state-machine model for Orca Menu mouse interaction logic.
\* Scope:
\* - explicit top-bar state and switching
\* - nested submenu open/close behavior
\* - deepest-hover vs ancestor-hover behavior
\* - ancestor click focus/retarget behavior
\* - disabled top-bar and popup item inertness
\* - outside click and back behavior
\* - keyboard activation of the selected row

TopMenus == {"FileTop", "EditTop", "ViewTop"}

Menus == {
  "FileMenu",
  "EditMenu",
  "ViewMenu",
  "ToolsMenu",
  "NestedMenu",
  "FormatMenu"
}

Actions == {
  "OpenAct",
  "DisabledAct",
  "CutAct",
  "TreeAct",
  "NextedAct",
  "DeepAct",
  "DeepTwoAct",
  "TrimAct"
}

Submenus == {
  "ToolsSub",
  "NestedSub",
  "FormatSub"
}

Items == Actions \cup Submenus
EventTarget == Items \cup TopMenus \cup {"None"}

EnabledTop(top) == top # "ViewTop"
EnabledItem(item) == item # "DisabledAct"

Kind(item) ==
  IF item \in Actions THEN "action" ELSE "submenu"

MenuForTop(top) ==
  CASE top = "FileTop" -> "FileMenu"
    [] top = "EditTop" -> "EditMenu"
    [] top = "ViewTop" -> "ViewMenu"

ChildMenu(item) ==
  CASE item = "ToolsSub" -> "ToolsMenu"
    [] item = "NestedSub" -> "NestedMenu"
    [] item = "FormatSub" -> "FormatMenu"

MenuItems(menu) ==
  CASE menu = "FileMenu" -> <<"OpenAct", "DisabledAct", "ToolsSub", "FormatSub">>
    [] menu = "EditMenu" -> <<"CutAct">>
    [] menu = "ViewMenu" -> <<"TreeAct">>
    [] menu = "ToolsMenu" -> <<"NestedSub", "NextedAct">>
    [] menu = "NestedMenu" -> <<"DeepAct", "DeepTwoAct">>
    [] menu = "FormatMenu" -> <<"TrimAct">>

FirstEnabledItem(menu) ==
  CASE menu = "FileMenu" -> "OpenAct"
    [] menu = "EditMenu" -> "CutAct"
    [] menu = "ViewMenu" -> "TreeAct"
    [] menu = "ToolsMenu" -> "NestedSub"
    [] menu = "NestedMenu" -> "DeepAct"
    [] menu = "FormatMenu" -> "TrimAct"

Frame(menu, selected) == [menu |-> menu, selected |-> selected]

FrameType == [menu : Menus, selected : Items]

IsItemInMenu(menu, item) ==
  \E idx \in 1..Len(MenuItems(menu)) : MenuItems(menu)[idx] = item

ChildFrame(item) ==
  Frame(ChildMenu(item), FirstEnabledItem(ChildMenu(item)))

VisibleLevels(stackValue) == 1..Len(stackValue)

VARIABLES open, activeTop, stack, ranAction, lastExecutedItem, lastEvent, prevStack, prevActiveTop

vars == <<open, activeTop, stack, ranAction, lastExecutedItem, lastEvent, prevStack, prevActiveTop>>

Meta(kind, level, target) ==
  /\ prevStack' = stack
  /\ prevActiveTop' = activeTop
  /\ lastEvent' = [kind |-> kind, level |-> level, target |-> target]

ClearAction ==
  /\ ranAction' = FALSE
  /\ lastExecutedItem' = "None"

OpenTopState(top) ==
  /\ open' = TRUE
  /\ activeTop' = top
  /\ stack' = <<Frame(MenuForTop(top), FirstEnabledItem(MenuForTop(top)))>>
  /\ ClearAction

Init ==
  /\ open = FALSE
  /\ activeTop = "FileTop"
  /\ stack = <<>>
  /\ ranAction = FALSE
  /\ lastExecutedItem = "None"
  /\ lastEvent = [kind |-> "Init", level |-> 0, target |-> "None"]
  /\ prevStack = <<>>
  /\ prevActiveTop = "FileTop"

OpenRoot ==
  /\ ~open
  /\ EnabledTop(activeTop)
  /\ Meta("OpenRoot", 1, activeTop)
  /\ OpenTopState(activeTop)

Hover(level, item) ==
  /\ open
  /\ level \in VisibleLevels(stack)
  /\ IsItemInMenu(stack[level].menu, item)
  /\ Meta("Hover", level, item)
  /\ activeTop' = activeTop
  /\ IF ~EnabledItem(item)
        THEN /\ open' = open
             /\ stack' = stack
             /\ ClearAction
      ELSE IF level < Len(stack)
        THEN /\ open' = open
             /\ stack' = stack
             /\ ClearAction
        ELSE /\ open' = open
             /\ stack' = [stack EXCEPT ![level].selected = item]
             /\ ClearAction

DeepestClick(level, item) ==
  IF Kind(item) = "submenu"
    THEN /\ open' = TRUE
         /\ activeTop' = activeTop
         /\ stack' = Append([stack EXCEPT ![level].selected = item], ChildFrame(item))
         /\ ClearAction
    ELSE /\ open' = FALSE
         /\ activeTop' = activeTop
         /\ stack' = <<>>
         /\ ranAction' = TRUE
         /\ lastExecutedItem' = item

AncestorClick(level, item) ==
  IF Kind(item) = "submenu"
    THEN IF stack[level].selected = item
           THEN /\ open' = TRUE
                /\ activeTop' = activeTop
                /\ stack' = SubSeq(stack, 1, level)
                /\ ClearAction
           ELSE /\ open' = TRUE
                /\ activeTop' = activeTop
                /\ stack' = Append([SubSeq(stack, 1, level) EXCEPT ![level].selected = item], ChildFrame(item))
                /\ ClearAction
    ELSE /\ open' = TRUE
         /\ activeTop' = activeTop
         /\ stack' = [SubSeq(stack, 1, level) EXCEPT ![level].selected = item]
         /\ ClearAction

Click(level, item) ==
  /\ open
  /\ level \in VisibleLevels(stack)
  /\ IsItemInMenu(stack[level].menu, item)
  /\ Meta("Click", level, item)
  /\ IF ~EnabledItem(item)
        THEN /\ open' = open
             /\ activeTop' = activeTop
             /\ stack' = stack
             /\ ClearAction
      ELSE IF level = Len(stack)
        THEN DeepestClick(level, item)
        ELSE AncestorClick(level, item)

ClickTop(top) ==
  /\ Meta("ClickTop", 0, top)
  /\ IF ~EnabledTop(top)
        THEN /\ open' = open
             /\ activeTop' = activeTop
             /\ stack' = stack
             /\ ClearAction
      ELSE IF open /\ activeTop = top
        THEN /\ open' = FALSE
             /\ activeTop' = activeTop
             /\ stack' = <<>>
             /\ ClearAction
        ELSE OpenTopState(top)

HoverTop(top) ==
  /\ Meta("HoverTop", 0, top)
  /\ IF ~open
        THEN /\ open' = open
             /\ activeTop' = activeTop
             /\ stack' = stack
             /\ ClearAction
      ELSE IF ~EnabledTop(top)
        THEN /\ open' = open
             /\ activeTop' = activeTop
             /\ stack' = stack
             /\ ClearAction
      ELSE IF activeTop = top
        THEN /\ open' = open
             /\ activeTop' = activeTop
             /\ stack' = stack
             /\ ClearAction
        ELSE OpenTopState(top)

ClickOutside ==
  /\ open
  /\ Meta("ClickOutside", 0, "None")
  /\ open' = FALSE
  /\ activeTop' = activeTop
  /\ stack' = <<>>
  /\ ClearAction

GoBack ==
  /\ open
  /\ Meta("GoBack", Len(stack), "None")
  /\ activeTop' = activeTop
  /\ IF Len(stack) > 1
        THEN /\ open' = TRUE
             /\ stack' = SubSeq(stack, 1, Len(stack) - 1)
             /\ ClearAction
        ELSE /\ open' = FALSE
             /\ stack' = <<>>
             /\ ClearAction

HoverAny ==
  \E level \in 1..Len(stack) :
    \E idx \in 1..Len(MenuItems(stack[level].menu)) :
      Hover(level, MenuItems(stack[level].menu)[idx])

ClickAny ==
  \E level \in 1..Len(stack) :
    \E idx \in 1..Len(MenuItems(stack[level].menu)) :
      Click(level, MenuItems(stack[level].menu)[idx])

ClickTopAny ==
  \E top \in TopMenus : ClickTop(top)

HoverTopAny ==
  \E top \in TopMenus : HoverTop(top)

ActivateSelected ==
  /\ open
  /\ LET selected == stack[Len(stack)].selected IN
     /\ Meta("ActivateSelected", Len(stack), selected)
     /\ IF Kind(selected) = "submenu"
        THEN /\ open' = TRUE
             /\ activeTop' = activeTop
             /\ stack' = Append(stack, ChildFrame(selected))
             /\ ClearAction
        ELSE /\ open' = FALSE
             /\ activeTop' = activeTop
             /\ stack' = <<>>
             /\ ranAction' = TRUE
             /\ lastExecutedItem' = selected

Next ==
  OpenRoot
  \/ HoverAny
  \/ ClickAny
  \/ ClickTopAny
  \/ HoverTopAny
  \/ ActivateSelected
  \/ ClickOutside
  \/ GoBack

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ open \in BOOLEAN
  /\ activeTop \in TopMenus
  /\ stack \in Seq(FrameType)
  /\ ranAction \in BOOLEAN
  /\ lastExecutedItem \in EventTarget
  /\ prevStack \in Seq(FrameType)
  /\ prevActiveTop \in TopMenus
  /\ lastEvent \in [kind : {"Init", "OpenRoot", "Hover", "Click", "ClickTop", "HoverTop", "ActivateSelected", "ClickOutside", "GoBack"},
                    level : Nat,
                    target : EventTarget]

StackWellFormed ==
  /\ open <=> Len(stack) > 0
  /\ Len(stack) = 0 \/ stack[1].menu = MenuForTop(activeTop)
  /\ \A level \in 1..Len(stack) :
       /\ IsItemInMenu(stack[level].menu, stack[level].selected)
       /\ EnabledItem(stack[level].selected)
  /\ \A level \in 2..Len(stack) :
       /\ stack[level - 1].selected \in Submenus
       /\ ChildMenu(stack[level - 1].selected) = stack[level].menu

HoverNeverExecutes ==
  lastEvent.kind \in {"Hover", "HoverTop"} => ~ranAction

AncestorHoverInert ==
  /\ lastEvent.kind = "Hover"
  /\ lastEvent.level < Len(prevStack)
  => /\ stack = prevStack
     /\ activeTop = prevActiveTop
     /\ open = (Len(prevStack) > 0)
     /\ ~ranAction

DisabledItemInert ==
  /\ lastEvent.kind \in {"Hover", "Click"}
  /\ lastEvent.target \in Items
  /\ ~EnabledItem(lastEvent.target)
  => /\ stack = prevStack
     /\ activeTop = prevActiveTop
     /\ open = (Len(prevStack) > 0)
     /\ ~ranAction

DisabledTopInert ==
  /\ lastEvent.kind \in {"ClickTop", "HoverTop"}
  /\ lastEvent.target \in TopMenus
  /\ ~EnabledTop(lastEvent.target)
  => /\ stack = prevStack
     /\ activeTop = prevActiveTop
     /\ open = (Len(prevStack) > 0)
     /\ ~ranAction

AncestorActionClickFocusOnly ==
  /\ lastEvent.kind = "Click"
  /\ lastEvent.level < Len(prevStack)
  /\ lastEvent.target \in Actions
  /\ EnabledItem(lastEvent.target)
  => /\ ~ranAction
     /\ open
     /\ activeTop = prevActiveTop
     /\ Len(stack) = lastEvent.level
     /\ stack[lastEvent.level].selected = lastEvent.target

AncestorSubmenuSameCloses ==
  /\ lastEvent.kind = "Click"
  /\ lastEvent.level < Len(prevStack)
  /\ lastEvent.target \in Submenus
  /\ prevStack[lastEvent.level].selected = lastEvent.target
  => /\ open
     /\ activeTop = prevActiveTop
     /\ Len(stack) = lastEvent.level
     /\ stack[lastEvent.level].selected = lastEvent.target
     /\ ~ranAction

AncestorSubmenuSwitches ==
  /\ lastEvent.kind = "Click"
  /\ lastEvent.level < Len(prevStack)
  /\ lastEvent.target \in Submenus
  /\ prevStack[lastEvent.level].selected # lastEvent.target
  => /\ open
     /\ activeTop = prevActiveTop
     /\ Len(stack) = lastEvent.level + 1
     /\ stack[lastEvent.level].selected = lastEvent.target
     /\ stack[lastEvent.level + 1].menu = ChildMenu(lastEvent.target)
     /\ ~ranAction

DeepestActionExecutes ==
  /\ lastEvent.kind = "Click"
  /\ lastEvent.level = Len(prevStack)
  /\ lastEvent.target \in Actions
  /\ EnabledItem(lastEvent.target)
  => /\ ranAction
     /\ lastExecutedItem = lastEvent.target
     /\ ~open
     /\ activeTop = prevActiveTop
     /\ stack = <<>>

DeepestSubmenuOpens ==
  /\ lastEvent.kind = "Click"
  /\ lastEvent.level = Len(prevStack)
  /\ lastEvent.target \in Submenus
  => /\ open
     /\ activeTop = prevActiveTop
     /\ Len(stack) = Len(prevStack) + 1
     /\ stack[lastEvent.level].selected = lastEvent.target
     /\ stack[Len(stack)].menu = ChildMenu(lastEvent.target)
     /\ ~ranAction

TopClickSameCloses ==
  /\ lastEvent.kind = "ClickTop"
  /\ EnabledTop(lastEvent.target)
  /\ Len(prevStack) > 0
  /\ prevActiveTop = lastEvent.target
  => /\ ~open
     /\ activeTop = prevActiveTop
     /\ stack = <<>>
     /\ ~ranAction

TopClickOtherOpens ==
  /\ lastEvent.kind = "ClickTop"
  /\ EnabledTop(lastEvent.target)
  /\ (~(Len(prevStack) > 0) \/ prevActiveTop # lastEvent.target)
  => /\ open
     /\ activeTop = lastEvent.target
     /\ Len(stack) = 1
     /\ stack[1].menu = MenuForTop(lastEvent.target)
     /\ stack[1].selected = FirstEnabledItem(MenuForTop(lastEvent.target))
     /\ ~ranAction

TopHoverClosedInert ==
  /\ lastEvent.kind = "HoverTop"
  /\ Len(prevStack) = 0
  => /\ ~open
     /\ activeTop = prevActiveTop
     /\ stack = <<>>
     /\ ~ranAction

TopHoverOtherSwitches ==
  /\ lastEvent.kind = "HoverTop"
  /\ Len(prevStack) > 0
  /\ EnabledTop(lastEvent.target)
  /\ prevActiveTop # lastEvent.target
  => /\ open
     /\ activeTop = lastEvent.target
     /\ Len(stack) = 1
     /\ stack[1].menu = MenuForTop(lastEvent.target)
     /\ stack[1].selected = FirstEnabledItem(MenuForTop(lastEvent.target))
     /\ ~ranAction

KeyboardActivateActionExecutes ==
  /\ lastEvent.kind = "ActivateSelected"
  /\ lastEvent.target \in Actions
  => /\ ranAction
     /\ lastExecutedItem = lastEvent.target
     /\ ~open
     /\ activeTop = prevActiveTop
     /\ stack = <<>>

KeyboardActivateSubmenuOpens ==
  /\ lastEvent.kind = "ActivateSelected"
  /\ lastEvent.target \in Submenus
  => /\ open
     /\ activeTop = prevActiveTop
     /\ Len(stack) = Len(prevStack) + 1
     /\ stack[Len(prevStack)].selected = lastEvent.target
     /\ stack[Len(stack)].menu = ChildMenu(lastEvent.target)
     /\ ~ranAction

OutsideAlwaysCloses ==
  lastEvent.kind = "ClickOutside" =>
    /\ ~open
    /\ activeTop = prevActiveTop
    /\ stack = <<>>
    /\ ~ranAction

BackShrinksOrCloses ==
  lastEvent.kind = "GoBack" =>
    IF Len(prevStack) > 1
      THEN /\ open
           /\ activeTop = prevActiveTop
           /\ Len(stack) = Len(prevStack) - 1
      ELSE /\ ~open
           /\ activeTop = prevActiveTop
           /\ stack = <<>>

=============================================================================
