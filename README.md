##About This Profile

This profile instantiates POWDER's Massive MIMO base station (Skylark Wireless Faros (R) with 64 antennas), and 2 Iris SDR clients connetec to a d430 machine. The profile also fetches the latest RENEWLab software with a wide variety of tools to work with Faros Massive MIMO base station, including MATLAB scripts for over-the-air many-antenna experiments, large-scale channel measurement, and many python tools for test and experimentation. To learn more about RENEWLab, see https://docs.renew-wireless.org

##Getting Started

After logging into pc1, RENEWLab software source is available at /local/repository.

To start a large-scale channel measurement:

`cd /local/repository/CC/Sounder<br />
cmake .<br />
make -j<br />
sudo ./sounder files/tddconfig_1cl.json`


