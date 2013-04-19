/*
 * Line.cpp
 *
 *  Created on: 2013/04/08
 *      Author: t-uchitane
 */

#include "Line.h"

Line::Line() {
	// TODO Auto-generated constructor stub
	car_count=0;
}

Line::Line(int l) {
	length = l;
	car_count=0;
}

Line::~Line() {
	// TODO Auto-generated destructor stub
}

int Line::get_car_count() {
	return car_count;
}

void Line::add_car_count() {
	car_count++;
}

int Line::getLength() {
	return length;
}
