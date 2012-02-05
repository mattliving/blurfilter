// COMS20600 - WEEKS 9 to 12
// ASSIGNMENT 3
// TITLE: "Concurrent Image Filter"
// Created by Matthew Livingston and Jamie Henson on 20/01/2012.
// Copyright 2012 University of Bristol. All rights reserved.

typedef unsigned char uchar;
#include <platform.h>
#include <stdio.h>
#include "pgmIO.h"
char infname[]   = "competition.pgm";   //put your input image path here
char outfname[]  = "testout.pgm"; //put your output image path here
out port cled[4] = {PORT_CLOCKLED_0,PORT_CLOCKLED_1,PORT_CLOCKLED_2,PORT_CLOCKLED_3};
out port cledG   = PORT_CLOCKLED_SELG;
out port cledR   = PORT_CLOCKLED_SELR;
in port  buttons = PORT_BUTTON;
out port speaker = PORT_SPEAKER;
#define SHUTDOWN 9997
#define START 9998
#define PAUSED 9999
#define IMWD 400
#define IMHT 256
#define WORKERS 4

// Read Image from pgm file with path and name infname[] to channel c_out
void DataInStream(chanend c_out) {
	int res, temp;
	uchar line[IMWD];
	cledG <: 1;
	printf( "DataInStream:Start...\n" );
	res = _openinpgm(infname, IMWD, IMHT);
	if (res) {
		printf( "DataInStream:Error opening %s\n.", infname );
		return;
	}
	for(int y = 0; y < IMHT; y++) {
		_readinline(line, IMWD);
		for(int x = 0; x < IMWD; x++) {	
			select {
				case c_out :> temp:
					if (temp == SHUTDOWN) {
						printf("DataInStream shutting down.\n");
						return;
					}
					break;
				default: c_out <: line[x]; break;
			}
		}
	}
	_closeinpgm();
	printf( "DataInStream:Done...\n" );
	return;
}

// Wait function
void waitMoment(uint myTime) {
	timer tmr;
	uint waitTime;
	tmr :> waitTime;
	waitTime += myTime;
	tmr when timerafter(waitTime) :> void;
}

// Displays an LED pattern in one quadrant of the clock LEDs
void visualiser(out port p, chanend fromCollector) {
	uint lightUpPattern;
	uint running = 1;
	while (running == 1) {
		select {
			case fromCollector :> lightUpPattern:
				if (lightUpPattern == SHUTDOWN) running = 0;
				else p <: lightUpPattern;
				break;
			default: break;
		}
	}
	printf("Visualiser has shutdown\n");
}

void buttonListener(in port buttons, chanend toDist) {
	int buttonInput;               //button pattern currently pressed
	uint running = 1, start = 0;   //helper variable to determine system shutdown
	while (running == 1) {
		buttons when pinsneq(15) :> buttonInput;
		if (buttonInput == 14) {
			if (start == 0) {
				toDist <: START;
				start = 1;
			}
		}
		if (buttonInput == 13) {
			toDist <: PAUSED;
			waitMoment(10000000);
		}
		if (buttonInput == 11) {
			toDist <: SHUTDOWN;
			toDist :> running;
		}
	}
	printf("buttonListener has shutdown\n");
}

void distributor(chanend c_in, chanend w_in[], chanend toButtons) {
	uchar val;
	uchar filtermap[IMWD*3+6];
	int temp[9];
	int busy[WORKERS];
	int idle = WORKERS;
	int i, k, b;
	uint running = 1, started = 0, paused = 0;
	
	while (running == 1) {
		select {
			case toButtons :> b:
				if (b == START && started == 0) {
					started = 1;
					printf("Processing started\n");

					// All workers are initially free
					for (int j = 0; j < WORKERS; j++) busy[j] = 0;

					// Read in first line of image
					for (int j = 1; j < IMWD+1; j++) {
						c_in :> val;
						filtermap[j]        = val;
						filtermap[IMWD+2+j] = val;
					}
					// Read in second line of image
					for (int j = IMWD*2+5; j < IMWD*3+5; j++) {
						c_in :> val;
						filtermap[j] = val;
					}
					
					// Edge values
					filtermap[0]        = filtermap[1];
					filtermap[IMWD+1]   = filtermap[IMWD];
					filtermap[IMWD+2]   = filtermap[IMWD+3];
					filtermap[IMWD*2+3] = filtermap[IMWD*2+2];
					filtermap[IMWD*2+4] = filtermap[IMWD*2+5];
					filtermap[IMWD*3+5] = filtermap[IMWD*3+4];

					i = 0;
					while (i < IMHT) {
						// Farm out the work
						k = 0;
						while (k < IMWD) {
							select {
								case toButtons :> b: 
									if (b == PAUSED) {
										if (paused == 0) {
											paused = 1;
											printf("System paused.\n");
										}
										else {
											paused = 0; 
											printf("System resumed.\n");
										}
									}
									else if (b == SHUTDOWN) {
										printf("Distibutor shutting down.\n");	
										for (int j = 0; j < WORKERS; j++) {
											select {
												case w_in[j] :> b: break;
												default: break;
											}
											w_in[j] <: SHUTDOWN;
										}
										select {
											case c_in :> val: break;
											default: break;
										}
										c_in <: SHUTDOWN;
										toButtons <: 0;
										return;
									}
									break;
								default: break;
							}
							if (paused == 0) {
								if (idle > 0) {
									temp[0] = (int) filtermap[k];
									temp[1] = (int) filtermap[k+1];
									temp[2] = (int) filtermap[k+2];
									temp[3] = (int) filtermap[k+IMWD+2];
									temp[4] = (int) filtermap[k+IMWD+3];
									temp[5] = (int) filtermap[k+IMWD+4];
									temp[6] = (int) filtermap[k+IMWD*2+4];
									temp[7] = (int) filtermap[k+IMWD*2+5];
									temp[8] = (int) filtermap[k+IMWD*2+6];

									// Look for free worker
									for (int j = 0; j < WORKERS; j++) { 
										if (busy[j] == 0) {
											// Send data to free worker
											for (int k = 0; k < 9; k++) {
												w_in[j] <: temp[k];
											}
											// Send current array index to worker
											w_in[j] <: k;
											busy[j] = 1; idle--;
											k++;
											//printf("Sent to worker %d\n", j);
											break;
										}
									}
								}
								else {
									// Receive ready signals from workers
									for (int j = 0; j < WORKERS; j++) {
										select 
										{
											case w_in[j] :> busy[j]: idle++; break;
											default: break;
										}
									}
								}
							}
						}

						// Shift the 2nd and 3rd rows back one row, effectively deleting the 1st row
						for (int j = 0; j < IMWD*2+4; j++) {
							filtermap[j] = filtermap[j+2+IMWD];
						}
						if (i < IMHT-2) {
							// Read in new values for the 3rd row
							for (int j = IMWD*2+5; j < IMWD*3+5; j++) {
								c_in :> val;
								filtermap[j] = val;
							}
							// Calculate edge values for new 3rd row
							filtermap[IMWD*2+4] = filtermap[IMWD*2+5];
							filtermap[IMWD*3+5] = filtermap[IMWD*3+4];
						}
						else {
							// Calculate edge values for bottom row
							for (int j = IMWD*2+4; j < IMWD*3+6; j++) {
								filtermap[j] = filtermap[j-2-IMWD];
							}
						}
						i++;
					}
				}
				// SHUTDOWN CASE
				else if (b == SHUTDOWN) {
					printf("Distributor shutting down.\n");
					running = 0;					
					for (int k = 0; k < WORKERS; k++) {
						select {
							case w_in[k] :> i: break;
							default: break;
						}
						w_in[k] <: SHUTDOWN;
					}
					if (started == 0) {
						select {
							case c_in :> val: break;
							default: break;
						}
						c_in <: SHUTDOWN;
					}
					toButtons <: 0;
					return;
				}
				break;
			default: break;
		}
	}
	return;
}

void worker(chanend c_in, chanend c_out) {
	uint running = 1;
	int sum, index, temp, i;
	while (running) {
		sum = 0; index = 0; temp = 0; i = 0;
		while (i < 9) {
			select {
				case c_in :> temp: 
					if (temp == SHUTDOWN) {
						printf("Worker shutting down.\n");
						c_out <: SHUTDOWN;
						return;
					}
					else {
						sum += temp;
						i++;
					}
					break;
				default: break;
			}
		}
		c_in :> index;
		if (index == SHUTDOWN) {
			c_out <: SHUTDOWN;
			printf("Worker shutting down.\n");
			return;
		}
		// Send result and index to collector
		c_out <: index;
		c_out <: (sum/9);
		// Tell distributer that worker is free
		select {
			case c_in :> temp:
				if (temp == SHUTDOWN) {
					c_out <: SHUTDOWN;
					printf("Worker shutting down.\n");
					return;
				}
				break;
			default: c_in <: 0; break;
		}
	}
}

void collector(chanend w_out[], chanend c_out, chanend show[]) {
	uint led = 0;
	int h = 0, i = 0, j = 0, temp, index, pixelCount = 0, totalPixels = (IMHT*IMWD)/12;
	uchar image[IMWD];

	while (h < IMHT) {
		i = 0;
		while (i < IMWD) {
			j = 0;
			while (j < WORKERS) {
				select {
					case w_out[j] :> temp: 
						if (temp == SHUTDOWN) {
							for (int k = 0; k < WORKERS; k++) {
								if (k != j) w_out[k] :> temp;
							}
							for (int k = 0; k < 4; k++) show[k] <: SHUTDOWN;
							c_out <: SHUTDOWN;
							printf("Collector shutting down.\n");
							return;
						}
						else {
							index = temp;
							w_out[j] :> temp;
							image[index] = temp;
							i++; j++; pixelCount++;
						}
						break;
					default: j++; break;
				}
				for (int k = 0; k < 4; k++) {
					temp = 0;
					for (int l = 0; l < led+1; l++) temp += (16<<(l%3)) * (l/3==k);
					show[k] <: temp;
				}
				if (pixelCount % totalPixels == 0) {
					if (pixelCount != 0) led++;
				}
			}
		}
		for (int k = 0; k < IMWD; k++) c_out <: (int)image[k];
		h++;
	}

	for (int k = 0; k < WORKERS; k++) w_out[k] :> temp;
	for (int k = 0; k < 4; k++) show[k] <: SHUTDOWN;
	printf("Collector shutting down.\n");
	return;
}

// Write pixel stream from channel c_in to pgm image file
void DataOutStream(chanend c_in) {
	int res, temp;
	uchar line[IMWD];
	printf( "DataOutStream:Start...\n" );
	res = _openoutpgm(outfname, IMWD, IMHT);
	if (res) {
		printf( "DataOutStream:Error opening %s\n.", outfname );
		return;
	}

	for (int y = 0; y < IMHT; y++) {
		for(int x = 0; x < IMWD; x++) {
			c_in :> temp;
			if (temp == SHUTDOWN) {
				printf("DataOutStream shutting down. \n");
				return;
			}
			line[x] = (uchar)temp;
		}
		_writeoutline(line, IMWD);
	}

	_closeoutpgm();
	printf( "DataOutStream:Done...\n" );
	return;
}

//MAIN PROCESS defining channels, orchestrating and starting the threads
int main(void) {
	chan c_inIO, c_outIO;
	chan w_in[WORKERS];	  // Channels between workers and DataInStream
	chan w_out[WORKERS];  // Channels between workers and Collector
	chan buttonToDist;    // Channel from buttonListener to Distributor
	chan show[4];	      // Channels for LED visualisation

	par {
		on stdcore[0] : DataInStream(c_inIO);
		on stdcore[0] : buttonListener(buttons, buttonToDist);
		on stdcore[1] : distributor(c_inIO, w_in, buttonToDist);
		// Thread replication for workers
		par (int k = 0; k < WORKERS; k++) {
			on stdcore[k%4]: worker(w_in[k], w_out[k]);
		}
		on stdcore[2] : collector(w_out, c_outIO, show);
		on stdcore[3] : DataOutStream(c_outIO);
		par (int k = 0; k < 4; k++) {
			on stdcore[k%4]: visualiser(cled[k], show[k]);
		}
	}
	return 0;
}
