/// Physical constants used across Vivited. Every value is a published figure;
/// sources are listed in docs/SCIENCE.md.
library;

/// IAU 2000 Mars reference sphere radius used by the USGS Jezero products (m).
const double marsRadiusM = 3396190.0;

/// Mean surface gravity (m/s²).
const double marsGravity = 3.721;

/// Length of a mean solar day on Mars — a sol (s).
const double solSeconds = 88775.244;

/// Sol length in Earth hours.
const double solHours = solSeconds / 3600.0;

/// Solar constant at 1 AU (W/m²).
const double solarConstant1Au = 1361.0;

/// Planetocentric, east-positive coordinates of the map centre (Jezero).
const double jezeroLat = 18.4446;
const double jezeroLon = 77.4509;
