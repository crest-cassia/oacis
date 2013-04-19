/*
 * Position.h
 *
 *  Created on: 2013/04/08
 *      Author: t-uchitane
 */

#ifndef POSITION_H_
#define POSITION_H_
enum SIDE {
	RIGHT = 0,
	LEFT,
	MAX_SIDE
};

class Position {
public:
	Position();
	virtual ~Position();
	int x;
};

#endif /* POSITION_H_ */
