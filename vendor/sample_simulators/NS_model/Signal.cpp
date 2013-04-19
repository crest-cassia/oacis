/*
 * Signal.cpp
 *
 *  Created on: 2013/04/08
 *      Author: t-uchitane
 */

#include "Signal.h"

Signal::Signal() {
	// TODO Auto-generated constructor stub
	m_signal = false;
}

Signal::Signal(int pos, int term, int offset) {
	// TODO Auto-generated constructor stub
	m_signal = false;
	m_term = term;
	m_step = offset;
	p.x = pos;
}

Signal::~Signal() {
	// TODO Auto-generated destructor stub
}

bool Signal::signal_is_green() {
	return m_signal;
}

void Signal::setsignal_red() {
	m_signal = false;
}

void Signal::setsignal_green() {
	m_signal = true;
}

void Signal::run() {
	m_step++;
	while (m_step > m_term) {
		m_signal = !m_signal;
		m_step -= m_term;
	}
}
