**Sources**
- Original source: https://capitalbikeshare.com/system-data
- API documentation: https://github.com/MobilityData/gbfs/tree/v2.3

**Brief**

Quasi-live monitoring of regional bikeshare station statuses based on station capacity using data from periodic API calls to enable sustained operational excellence.

Note: in-progress

**Detail**

...

**For consideration**

- Here, more % of time spent 'in use' is taken to mean a station has a healthy inflow and outflow of bikes.
However, a station could  be abandoned and left in status with constant 50% fullness.
So, consider way to describe stations with lack of movement over extended times.
By this same logic, a station spending majority time in an even split of near empty and near full is the healthiest - current PBI does not highlight this well.
