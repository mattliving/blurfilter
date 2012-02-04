/*
 * derp.xc
 *
 *  Created on: Dec 20, 2011
 *      Author: jamie
 */

#ifndef PGMIO_H_ 
#define PGMIO_H_ 
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
///////////////////////////////////////////////////////////////////////////////////////////// 
// 
// standard pgm input and output routines 
// 
// Input is a referenced array of unsigned chars of width and height and a 
// referenced char array of the system path to destination, e.g. 
// "/home/user/xmos/project/" on Linux or "C:\\user\\xmos\\project\\" on Windows 
// 
///////////////////////////////////////////////////////////////////////////////////////////// 
int _writepgm(unsigned char x[], int height, int width, char fname[]); 
int _readpgm(unsigned char x[], int height, int width, char fname[]);
/////////////////////////////////////////////////////////////////////////////////////////////
//
// Line-wise pgm input routines: open file, read a line, close the file
//
/////////////////////////////////////////////////////////////////////////////////////////////
int _openinpgm(char fname[], int width, int height); 
int _readinline(unsigned char line[], int width); 
int _closeinpgm(); 
/////////////////////////////////////////////////////////////////////////////////////////////
//
// Line-wise pgm output routines: open file, read a line, close the file
//
/////////////////////////////////////////////////////////////////////////////////////////////
int _openoutpgm(char fname[], int width, int height); 
int _writeoutline(unsigned char line[], int width); 
int _closeoutpgm(); 
#endif /*PGMIO_H_*/
