/*
 * Caragent.h
 *
 *  Created on: 2013/04/08
 *      Author: t-uchitane
 */

#include "Agentparameter.h"
#include "Object.h"
#include <stdlib.h>
#include <stdio.h>
#ifndef CARAGENT_H_
#define CARAGENT_H_

class Car_agent : public Traffic_Object {
	public:
		static bool sort_right(const Car_agent& rLeft, const Car_agent& rRight) { return rLeft.p.x < rRight.p.x; }
		static bool sort_left(const Car_agent& rLeft, const Car_agent& rRight) { return rLeft.p.x > rRight.p.x; }
		Car_agent();
		Car_agent(Agentparameter ap);
		virtual ~Car_agent();
		int getAgentPos();
		void run();
		void run(Traffic_Object other);
		int get_initial_pos();
		SIDE get_side();
		int velocity;
//		bool Car_agent_Compare_right(const Car_agent& c1, const Car_agent& c2);
	private:
		Agentparameter m_agentparameter;
};
#endif /* CARAGENT_H_ */
