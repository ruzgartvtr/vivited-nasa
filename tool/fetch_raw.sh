#!/usr/bin/env bash
# Downloads the raw NASA / USGS source products used by the offline processing
# scripts into tool/raw/ (≈ 80 MB). Nothing here is needed to run the app: the
# processed assets are already in assets/.
set -euo pipefail
cd "$(dirname "$0")" && mkdir -p raw && cd raw
CTX=https://asc-pds-services.s3.us-west-2.amazonaws.com/mosaic/mars2020_trn/CTX
curl -fLO "$CTX/JEZ_ctx_B_soc_008_DTM_MOLAtopography_DeltaGeoid_20m_Eqc_latTs0_lon0.tif"
curl -fLO "$CTX/JEZ_ctx_B_soc_008_DTM_MOLAtopography_DeltaGeoid_20m_Eqc_latTs0_lon0.lbl"
curl -fLO "$CTX/JEZ_ctx_B_soc_008_orthoMosaic_6m_Eqc_latTs0_lon0.tif"
curl -fLO "$CTX/JEZ_ctx_B_soc_008_orthoMosaic_6m_Eqc_latTs0_lon0.lbl"
curl -fLO "https://pds-geosciences.wustl.edu/mgs/mgs-m-mola-5-megdr-l3-v1/mgsl_300x/meg016/megt90n000eb.img"
curl -fLO "https://mars.nasa.gov/mmgis-maps/M20/Layers/json/M20_traverse.json"
curl -fLO "https://mars.nasa.gov/mmgis-maps/M20/Layers/json/M20_waypoints.json"
echo "Raw data ready. Next: python3 ../process_terrain.py && python3 ../build_targets.py && python3 ../process_meda.py"
