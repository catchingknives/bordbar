# ICE portal API notes

Undocumented. DB publishes nothing; everything here is from probing the portal on board (autumn 2026, a BR 403 trainset) and from community code:

- `felix-zenk/iceportal-apis` (Python, archived 2024-07-11, now a thin wrapper)
- `felix-zenk/onboardapis` (its successor, active, last push 2026-04-14): `onboardapis/train/de/db/apis.py` and `interfaces.py`

Only reachable on WIFIonICE. No auth, no CORS headers.

## Endpoints

| Path | Response | What it is |
|---|---|---|
| `/api1/rs/status` | 200 | Speed, GPS, train class/series, trainset (`tzn`), coach class, WiFi quality, server time |
| `/api1/rs/tripInfo/trip` | 200 | Whole journey: stops, times, delays, platforms, distances, delay reasons |
| `/api1/rs/tripInfo/connection/{evaNr}` | 404 | Connecting trains at a stop (`connections` array). 404 for the next stop and for one further ahead; unknown whether it fills in closer to arrival |
| `/api1/rs/pois/map/{lat1}/{lon1}/{lat2}/{lon2}` | 200, empty | Points of interest in a bounding box; returned `{"pois":[]}` for the current area |
| `/api1/rs/page/hoerbuecher` | 200 | Audiobook catalogue page (93 KB CMS JSON), not useful here |
| `/bap/api/bap-service-status` | 404 | At-seat service (1st class). Now redirects to `/bap/api/public/...`, which also 404s |

## Fields worth knowing

- `status.connectivity.{currentState, nextState, remainingTimeSeconds}`: an internet forecast ("WiFi drops to WEAK in 120 s"). onboardapis reads it; it was absent from our status response, so it is train- or route-dependent.
- `status.bapInstalled`: whether at-seat service exists on this train (absent from ours).
- `trip.actualPosition`: unreliable. Read 8.5 km while the train was 60+ km past Südkreuz. onboardapis computes position as `actualPosition + distanceFromLastStop`, which would also have been wrong here; Bordbar uses the last stop's `distanceFromStart + distanceFromLastStop`.
- `trip.stopInfo.actualNext / actualLast / finalStationName`: reliable.
- Times are epoch milliseconds; delays are strings like `"+2"` or `""`.

## Trainset names

ICE trainsets carry city names. onboardapis ships a `tzn` number to name table (`onboardapis/train/de/db/mappings.yaml`, 366 entries, some marked uncertain). The trainset we probed was not in it.
