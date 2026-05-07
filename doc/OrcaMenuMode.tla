----------------------------- MODULE OrcaMenuMode -----------------------------
EXTENDS TLC

\* Abstract mode-handoff model for Orca Menu entry and exit behavior.
\*
\* Scope:
\* - editor mode before Orca entry
\* - explicit Orca entry via open key or actionable top-bar click
\* - inert top-bar clicks that must not disturb editor mode
\* - preservation of visual selection context while Orca is active
\* - clearing preserved context when Orca actually exits

EditorModes == {"Normal", "Visual", "Insert"}
ClickKinds == {"ValidTop", "DisabledTop", "MissTop"}
CtxStates == {"None", "VisualPreserved"}
ExitReasons == {"None", "Escape", "OutsideClick", "Action", "OtherExit"}

VARIABLES editorMode, orcaActive, visualCtx, lastEvent, lastClick, lastExitReason

Vars == <<editorMode, orcaActive, visualCtx, lastEvent, lastClick, lastExitReason>>

TypeOK ==
  /\ editorMode \in EditorModes
  /\ orcaActive \in BOOLEAN
  /\ visualCtx \in CtxStates
  /\ lastEvent \in {
       "Init",
       "OpenKey",
       "TopBarClick",
       "OrcaExit"
     }
  /\ lastClick \in ClickKinds \cup {"None"}
  /\ lastExitReason \in ExitReasons

Init ==
  /\ editorMode = "Visual"
  /\ orcaActive = FALSE
  /\ visualCtx = "None"
  /\ lastEvent = "Init"
  /\ lastClick = "None"
  /\ lastExitReason = "None"

PreserveCtxForEntry(mode) ==
  IF mode = "Visual" THEN "VisualPreserved" ELSE "None"

OpenKey ==
  /\ ~orcaActive
  /\ lastEvent' = "OpenKey"
  /\ lastClick' = "None"
  /\ lastExitReason' = "None"
  /\ orcaActive' = TRUE
  /\ visualCtx' = PreserveCtxForEntry(editorMode)
  /\ editorMode' = "Normal"

TopBarClick(kind) ==
  /\ ~orcaActive
  /\ kind \in ClickKinds
  /\ lastEvent' = "TopBarClick"
  /\ lastClick' = kind
  /\ lastExitReason' = "None"
  /\ IF kind = "ValidTop"
        THEN /\ orcaActive' = TRUE
             /\ visualCtx' = PreserveCtxForEntry(editorMode)
             /\ editorMode' = "Normal"
        ELSE /\ orcaActive' = orcaActive
             /\ visualCtx' = visualCtx
             /\ editorMode' = editorMode

OrcaExit(reason) ==
  /\ orcaActive
  /\ reason \in ExitReasons \ {"None"}
  /\ lastEvent' = "OrcaExit"
  /\ lastClick' = "None"
  /\ lastExitReason' = reason
  /\ orcaActive' = FALSE
  /\ editorMode' = "Normal"
  /\ visualCtx' = "None"

OpenKeyStep == OpenKey

TopBarClickStep ==
  \E kind \in ClickKinds : TopBarClick(kind)

OrcaExitStep ==
  \E reason \in ExitReasons \ {"None"} : OrcaExit(reason)

Next ==
  OpenKeyStep
  \/ TopBarClickStep
  \/ OrcaExitStep

Spec == Init /\ [][Next]_Vars

\* Invariants that capture the intended UX contract.

OpenKeyAlwaysEnters ==
  lastEvent = "OpenKey" =>
    /\ orcaActive
    /\ editorMode = "Normal"

VisualOpenKeyPreservesCtx ==
  lastEvent = "OpenKey" /\ visualCtx = "VisualPreserved" => orcaActive

NonActionableClickNeverEnters ==
  lastEvent = "TopBarClick" /\ lastClick \in {"DisabledTop", "MissTop"} =>
    /\ ~orcaActive

NonActionableClickNeverCreatesCtx ==
  lastEvent = "TopBarClick" /\ lastClick \in {"DisabledTop", "MissTop"} =>
    visualCtx = "None"

ActionableClickEntersNormal ==
  lastEvent = "TopBarClick" /\ lastClick = "ValidTop" =>
    /\ orcaActive
    /\ editorMode = "Normal"

CtxOnlyWhileOrcaActive ==
  visualCtx = "VisualPreserved" => orcaActive

ExitAlwaysClearsCtx ==
  lastEvent = "OrcaExit" =>
    /\ ~orcaActive
    /\ visualCtx = "None"
    /\ editorMode = "Normal"

=============================================================================
