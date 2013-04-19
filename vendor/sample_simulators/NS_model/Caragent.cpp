/*
 * Caragent.cpp
 *
 *  Created on: 2013/04/08
 *      Author: t-uchitane
 */

#include "Caragent.h"

Car_agent::Car_agent() {
	// TODO Auto-generated constructor stub
	velocity = 0;

}

Car_agent::~Car_agent() {
	// TODO Auto-generated destructor stub
}

Car_agent::Car_agent(Agentparameter ap) {
	m_agentparameter = ap;
	p.x = ap.p.x;
	velocity = ap.max_velocity;
}

int Car_agent::getAgentPos() {
	return p.x;
}

void Car_agent::run(Traffic_Object other) {
	velocity++;
	if(velocity > m_agentparameter.max_velocity) {
		velocity = m_agentparameter.max_velocity;
	}
	if(m_agentparameter.m_side == LEFT) {
//		printf("diff=%d,",other.p.x - p.x);
		if(abs(other.p.x - p.x) <= velocity) {
			velocity = abs(other.p.x - p.x) -1;
//			if(velocity < 0) {
//				printf("other_pos=%d, my_pos=%d\n",other.p.x, p.x);
//			}
		}
		p.x -= velocity;
	} else if (m_agentparameter.m_side == RIGHT) {
//		printf("diff=%d,",other.p.x - p.x);
		if(abs(other.p.x - p.x) <= velocity) {
			velocity = abs(other.p.x - p.x) -1;
//			if(velocity < 0) {
//				printf("other_pos=%d, my_pos=%d\n",other.p.x, p.x);
//			}
		}
		p.x += velocity;
	}
}
void Car_agent::run() {
	velocity++;
	if(velocity > m_agentparameter.max_velocity) {
		velocity = m_agentparameter.max_velocity;
	}
	if(m_agentparameter.m_side == LEFT) {
		p.x -= velocity;
	} else if (m_agentparameter.m_side == RIGHT) {
		p.x += velocity;
	}
}

int Car_agent::get_initial_pos() {
	return m_agentparameter.p.x;
}

SIDE Car_agent::get_side() {
	return m_agentparameter.m_side;
}
