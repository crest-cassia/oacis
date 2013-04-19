/*
 * Signal.h
 *
 *  Created on: 2013/04/08
 *      Author: t-uchitane
 */

#include "Object.h"
#ifndef SIGNAL_H_
#define SIGNAL_H_

class Signal : public Traffic_Object {
public:
	Signal();
	Signal(int pos, int term, int offset);
	virtual ~Signal();
	bool signal_is_green();
	void setsignal_red();
	void setsignal_green();
	void run();
private:
	bool m_signal;
	int m_term;
	int m_step;
};

#endif /* SIGNAL_H_ */
