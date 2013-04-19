/*
 * Map.h
 *
 *  Created on: 2013/04/08
 *      Author: t-uchitane
 */
#include <vector>
#include <stdio.h>
#include <fstream>
#include <algorithm>
#include "Line.h"
#include "Object.h"
#include "Caragent.h"
#include "Signal.h"
#include "Mapparameter.h"
#include "Position.h"
#ifndef MAP_H_
#define MAP_H_

class Map {
public:
	Map();
	Map(Map_parameter mp);
	virtual ~Map();
	void addcars(SIDE s, int MAXV);
	void run();
	void writefile();
	void show();
//	void addsignal(Signal s);
//	std::vector<Car_agent> getCar_agent_vector(SIDE s);
//	Line getLine(SIDE s);
	std::vector<Line> line;
	std::vector<std::vector<Car_agent> > agent;
	std::vector<Signal> signal;
private:
	Map_parameter m_mapparameter;
};

#endif /* MAP_H_ */
