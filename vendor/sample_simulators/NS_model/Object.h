/*
 * Object.h
 *
 *  Created on: 2013/04/08
 *      Author: t-uchitane
 */
#include "Position.h"
#ifndef OBJECT_H_
#define OBJECT_H_

class Traffic_Object {
public:
	Traffic_Object();
	virtual ~Traffic_Object();
	Position p;
};

#endif /* OBJECT_H_ */
