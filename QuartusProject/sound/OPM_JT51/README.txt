If you want to use JT51 for OPM implemenation, please see the project below:
https://github.com/kunichiko/FPGA-X68k-DE0CV-OPM-JT51

I coudn't import JT51 here because JT51 is licensed under GPLv3. 
So if you want to use it, you have to bring these two files into this folder:

* jt51_1v1.v
* OPM_JT51.vhd

In addition, open X68DE0CVDEMU2.vhd and replace two `OPM` strings with `OPM_JT51`. 