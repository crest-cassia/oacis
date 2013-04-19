/*
 * Agentparameter.cpp
 *
 *  Created on: 2013/04/08
 *      Author: t-uchitane
 */

#include "Agentparameter.h"

Agentparameter::Agentparameter() {
	// TODO Auto-generated constructor stub

}

Agentparameter::~Agentparameter() {
	// TODO Auto-generated destructor stub
}

Agentparameter::Agentparameter(int position, int max_v, SIDE s) {
	p.x = position;
	max_velocity = max_v;
	m_side = s;
}
