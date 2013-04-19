/*
 * Line.h
 *
 *  Created on: 2013/04/08
 *      Author: t-uchitane
 */

#ifndef LINE_H_
#define LINE_H_

class Line {
public:
	Line();
	Line(int l);
	virtual ~Line();
	int get_car_count();
	void add_car_count();
	int getLength();
private:
	int length;
	int car_count;
};

#endif /* LINE_H_ */
