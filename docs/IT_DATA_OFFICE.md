# Factory IT & Data Management Office — design notes

Second selectable office branch (Settings → office). Two departments, one floor.

## Researched flows (sources in repo history)

**IT Management (Infrastructure / Network / Security)** — ITIL service
operation: the SERVICE DESK is the single point of contact; incidents and
requests enter there, get triaged into tiers, and escalate to Technical
Management. The NOC monitors infrastructure events 24/7 (event -> alarm ->
correlate -> acknowledge -> resolve) and modern NOC layouts put console
rows facing one shared video wall. Security operates as a separate dark
room (SOC) with its own screens. Server rooms are their own zone: rack
rows, cold aisle, CRAC cooling, overhead cable trays, glass separation.

**Data Management (AWS / ERP / AI / Software)** — manufacturing data flow:
PLC/SCADA + MES + ERP (SAP-class) data lands in a cloud data lake (AWS
AppFlow -> S3 -> Glue), engineers transform it, analysts/ML build models
(SageMaker-class) and dashboards feed back to operations. The ERP war room
hosts change management and integration planning; the Data & AI Lab holds
the GPU cluster and modelling benches.

## Floor plan (map_it.json, 24x19)

- N-center: **NOC** — 3-panel video wall + the live TownTV broadcast,
  two console rows facing it. Researcher station.
- NW: **IT Infrastructure** — workstations, spares shelving, one rack. Writer.
- Center door: **Service Desk** counter facing the walkway (ITIL SPOC).
- SW: **SOC** — dark floor, red accent light, threat screens. Editor.
- Center-S: **Server Room** — glass-walled, 8 LED racks in two rows,
  cold aisle, CRAC unit, cable tray, cool blue light.
- NE: **Data & AI Lab** — GPU cluster (glow), modelling bench. Publisher.
- E: **ERP War Room** — glass, round table + shells, KPI screen. Director.
- SE: pantry deck (coffee, stools, fridge).

## Mapping to the crew

Same five agents, same pipeline; workstations remap per map_it.json
buildings. Build mode, catalog, wall/floor tools all work here unchanged.
