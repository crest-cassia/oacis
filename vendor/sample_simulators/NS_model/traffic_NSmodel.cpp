//============================================================================
// Name        : traffic_NSmodel.cpp
// Author      : Takeshi Uchitane
// Version     :
// Copyright   : Your copyright notice
// Description : Hello World in C++, Ansi-style
//============================================================================

#include <iostream>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include "Mapparameter.h"
#include "Map.h"

using namespace std;

double CalPois(double a, double n);
double Fact(double n);

int Pois(double lambda)
{
	int k=0;
	double l=exp(-lambda);
	double m=1;
	do
	{
	    k++;
	    m*=rand()/double(RAND_MAX);
	}while(m>=l);
	return k-1;
}

int main(int argc, char** argv) {
	printf("seed=%ld\n",atol(argv[1]));
    /* 乱数系列の変更 */
    srand((unsigned) atol(argv[1]));

	printf("MAX_T=%d\n",atoi(argv[2]));
	int MAX_T = atoi(argv[2]);
	printf("length=%d\n",atoi(argv[3]));
	Map_parameter mp;
	mp.line_lenght = atoi(argv[3]);
	Map map(mp);
	printf("MAX_V=%d\n",atoi(argv[4]));
	int MAX_V = atoi(argv[4]);
	printf("lambda=%f\n",atof(argv[5]));
	int LAMBDA = atof(argv[5]);
	printf("signal_str=%s\n",argv[6]);
	int signal_input = 6;
  int max_signal_term = 0;
	while(signal_input < argc) {
		printf("signal_str=%s\n",argv[signal_input]);
		printf("signal_pos1=%d\n",atoi(argv[signal_input+1]));
		printf("signal_term=%d\n",atoi(argv[signal_input+2]));
		printf("signal_offset=%d\n",atoi(argv[signal_input+3]));
		map.signal.push_back(Signal(atoi(argv[signal_input+1]), atoi(argv[signal_input+2]), atoi(argv[signal_input+3])));
		signal_input+=4;
    int signal_term = atoi(argv[signal_input+2]);
    if( max_signal_term < signal_term ) {
      max_signal_term = signal_term;
    }
	}

	std::ofstream ofs;
	ofs.open( "map.txt");
				ofs << mp.line_lenght << std::endl;
	ofs.close();
	// ofs.open( "result.txt");
	// ofs.close();

	// int counter[(int)MAX_SIDE];
	// for(int i=0;i<(int)MAX_SIDE;i++) {
	// 	counter[i] = Pois(LAMBDA);
	// }

  int initial_step = max_signal_term * 10000;
  const int nTotalTime = initial_step + MAX_T;
  long nTotalAgents = 0;
	for(int time=0;time<nTotalTime;time++) {
		//add agent
		for(int side=0;side<(int)MAX_SIDE;side++) {
			// if(counter[side] > 0) {
			// 	counter[side]--;
			// } else {
			if( rand() / double(RAND_MAX) < 1.0 / LAMBDA) {
				map.addcars((SIDE)side, MAX_V);
				// counter[side]=Pois(1);
			}
		}
//		if(time < 3) {
//			map.addcars(RIGHT);
//			map.addcars(LEFT);
//		}
//		for(int side=0;side<(int)MAX_SIDE;side++) {
//			for(std::vector<Car_agent>::iterator it=map.agent.at(side).begin();it!=map.agent.at(side).end();++it) {
//				printf("(%d,%d),",(*it).p.x, (*it).velocity);
//			}
//			printf("\n");
//		}
//		map.show();
    if(time >= initial_step) {
		  map.writefile();
    }
		map.run();
    // std::cout << "There are " << map.agent[0].size() << " cars" << std::endl;
    nTotalAgents += map.agent[0].size();
	}
	map.writefile();
	for(int side=0;side<(int)MAX_SIDE;side++) {
//		printf("side=%d, count=%d\n",side,map.line.at(side).get_car_count());
	}
	ofs.open( "result.txt");
  ofs << static_cast<double>(nTotalAgents)/nTotalTime << std::endl;
  //ofs << "#side,throughput" << std::endl;
	//for(int side=0;side<(int)MAX_SIDE;side++) {
    //ofs << side << "," << static_cast<double>(map.line.at(side).get_car_count())/nTotalTime << std::endl;
	//}
	ofs.close();
//	for(int side=0;side<(int)MAX_SIDE;side++) {
//		for(std::vector<Car_agent>::iterator it=map.agent.at(side).begin();it!=map.agent.at(side).end();++it) {
//			printf("%d\n",(*it).p.x);
//		}
//	}
	return 0;
}
