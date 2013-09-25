/*****************************************************/
/*This file is written in CASSIYA Project since 2013.*/
/*****************************************************/

#include <sstream>
#include <iostream>
#include <fstream>
#include <string>
#include <math.h>
#include <stdlib.h>

using namespace std;

int main(int args, char** argv) {
	double p1, p2;
	unsigned long seed;
	//check arguments
	if(args!=4) {
		cerr << "Three arguments are necessary for this simulator." << endl;
		return -1;
	} else {
		p1 = atof(argv[1]);
		p2 = atof(argv[2]);
		seed = atol(argv[3]);
		srand(seed);
		cout << "p1=" << p1 << " p2=" << p2 << " seed=" << seed << endl;
	}

	//Init
	double phi1=0,phi2=M_PI*(rand()/(RAND_MAX +1.0)),w1=p1,w2=p2;
	int iteration = 2000;
	double** result = new double*[iteration];
	for(int i=0;i<iteration;i++) {
		result[i] = new double[3];
	}

	//sample simulation
	for(int t=0;t<iteration;t++) {
		result[t][0]=sin(phi1);
		result[t][1]=sin(phi2);
		double dy = result[t][0] - result[t][1];
		result[t][2]=dy;
		phi1 += 0.05*(M_PI + w1*dy);
		phi2 += 0.05*(M_PI + w2*dy);
	}

	//output time-series
	ofstream ofs( "time_series.dat" );
	if (ofs.is_open()) {
	ofs << "#t y1 y2 dy" << endl;
	for(int i=0;i<iteration;i++) {
		ofs << i << " " << result[i][0] << " " << result[i][1] << " " << result[i][2] << endl;
	}
	ofs.close();
	} else {
		cerr << "can not open result file." << endl;
		return -2;
	}

	for(int i=0;i<iteration;i++) {
		delete[] result[i];
	}
	delete[] result;

	return 0;
}
