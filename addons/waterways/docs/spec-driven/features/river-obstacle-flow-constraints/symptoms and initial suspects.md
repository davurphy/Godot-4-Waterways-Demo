# Symptoms And Initial Suspects

## Observed Symptoms

River flow does not reliably respect banks, shallow rocks, protruding rocks, bank-attached obstacles, and rock clusters. In some spots, water appears to flow through rocks instead of splitting and moving around them.

This is most visible where rocks protrude above the water surface or extend out from the river bank. The current bank and obstacle detection is producing useful data, but the final flow field does not always enforce those constraints strongly enough.

## Initial Suspects

- Obstacle detection may not be waterline-aware enough; flow should react to the wetted footprint, not the full visible top footprint.
- Hard obstacle masks may be too weak, narrow, blurred, or inconsistent to fully block flow.
- Local normal-based steering may create small deflections while still leaving flow vectors that point through obstacle clusters.
- Bank-attached protrusions may be classified as ordinary bank, shallow terrain, or soft friction instead of hard flow constraints.
- Rock clusters may need a stronger avoidance field or relaxation pass so flow routes around the group instead of through gaps that are visually blocked.
- Objects with wide tops and narrow waterline intersections may need explicit water-obstacle proxies or waterline slice classification.
- Visible shader flow and WaterSystem flow may need parity checks if physics-facing flow is expected to match visual flow.

## Diagnostic Frame

Incorrect obstacle flow should be investigated as a flow-constraint problem. The key question is whether the system has a reliable field that says where water is open, shallow, slowed, blocked, bank-bound, or forced to steer.

## Proposed Processing Order To Validate

river shape -> waterline obstacle classification -> corrected flow field -> bank/shallow drag -> pillows/wakes/foam -> visible shader

## Early Priority

Start by proving whether hard protrusions and bank-attached obstacles are represented correctly in raw diagnostic maps. If the raw maps are wrong, fix classification. If raw maps are correct but water still flows through obstacles, fix the flow steering or solver stage.
