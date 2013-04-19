/*
 * Agentparameter.h
 *
 *  Created on: 2013/04/08
 *      Author: t-uchitane
 */

#include "Position.h"
#ifndef AGENTPARAMETER_H_
#define AGENTPARAMETER_H_


class Agentparameter {
public:
	Agentparameter();
	Agentparameter(int position,int max_v, SIDE s);
	virtual ~Agentparameter();
	Position p;
	int max_velocity;
	SIDE m_side;
};

#endif /* AGENTPARAMETER_H_ */
