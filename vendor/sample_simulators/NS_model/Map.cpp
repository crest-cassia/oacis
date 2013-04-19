/*
 * Map.cpp
 *
 *  Created on: 2013/04/08
 *      Author: t-uchitane
 */

#include "Map.h"

Map::Map() {
	// TODO Auto-generated constructor stub

}

Map::~Map() {
	// TODO Auto-generated destructor stub
}

Map::Map(Map_parameter mp) {
	m_mapparameter = mp;
	for(int i=0;i<(int)MAX_SIDE;i++) {
		line.push_back(Line(m_mapparameter.line_lenght));
		std::vector<Car_agent> a;
		agent.push_back(a);
	}
}

void Map::addcars(SIDE s, int MAXV) {
	if(s == LEFT) {
		Agentparameter ap(m_mapparameter.line_lenght - 1, MAXV, LEFT);
		if(agent.at((int)LEFT).empty() || agent.at((int)LEFT).back().p.x != m_mapparameter.line_lenght - 1) {
			agent.at((int)LEFT).push_back(Car_agent(ap));
		}
	}
	if(s == RIGHT) {
		Agentparameter ap(0, MAXV, RIGHT);
		if(agent.at((int)RIGHT).empty() || agent.at((int)RIGHT).front().p.x != 0 ) {
			agent.at((int)RIGHT).push_back(Car_agent(ap));
		}
	}
}

void Map::run() {
	for(std::vector<Signal>::iterator it=signal.begin();it!=signal.end();++it) {
		(*it).run();
	}
	for(int side=0;side<(int)MAX_SIDE;side++) {
		if(!agent.at((int)side).empty()) {
			if(side == (int) RIGHT) {
				std::sort(agent.at(side).begin(), agent.at(side).end(), Car_agent::sort_right);
			}
			if(side == (int) LEFT) {
				std::sort(agent.at(side).begin(), agent.at(side).end(), Car_agent::sort_left);
			}
			for(std::vector<Car_agent>::iterator it=agent.at((int)side).begin();it!=agent.at(side).end();++it) {
				if(side == (int)RIGHT ) {
					std::vector<Signal>::iterator it_signal = signal.begin();//Signalは位置の小さい順に入っていると仮定
					while(((*it).p.x > (*it_signal).p.x) && (it_signal+1)!=signal.end()) {
						++it_signal;
					}
					if((*it).p.x >= (*it_signal).p.x || (*it_signal).signal_is_green()) {
						if((it+1) == agent.at(side).end()) {
//							printf("1pos=%d,signalpos=%d\n",(*it).p.x,(*it_signal).p.x);
							(*it).run();//printf("end\n");
						} else {
							std::vector<Car_agent>::iterator it2 = it;
							++it2;
//							printf("2pos=%d,other=%d\n",(*it).p.x,(*it2).p.x);
							(*it).run(*it2);
						}
					} else {
						if((it+1) == agent.at(side).end()) {
//							printf("3pos=%d,signalpos=%d\n",(*it).p.x,(*it_signal).p.x);
							(*it).run(*it_signal);//printf("end\n");
						} else {
							std::vector<Car_agent>::iterator it2 = it;
							++it2;
							if((*it2).p.x > (*it_signal).p.x) {
//								printf("4pos=%d,signalpos=%d\n",(*it).p.x,(*it_signal).p.x);
								(*it).run(*it_signal);
							} else {
//								printf("5pos=%d,other=%d\n",(*it).p.x,(*it2).p.x);
								(*it).run(*it2);
							}
						}
					}
				} else {
					std::vector<Signal>::reverse_iterator it_signal = signal.rbegin();//Signalは位置の小さい順に入っていると仮定
					while(((*it).p.x < (*it_signal).p.x) && (it_signal+1)!=signal.rend()) {
						++it_signal;
					}
					if((*it).p.x <= (*it_signal).p.x || (*it_signal).signal_is_green()) {
						if((it+1) == agent.at(side).end()) {
//							printf("1pos=%d,signalpos=%d\n",(*it).p.x,(*it_signal).p.x);
							(*it).run();//printf("end\n");
						} else {
							std::vector<Car_agent>::iterator it2 = it;
							++it2;
//							printf("2pos=%d,other=%d\n",(*it).p.x,(*it2).p.x);
							(*it).run(*it2);
						}
					} else {
						if((it+1) == agent.at(side).end()) {
//							printf("3pos=%d,signalpos=%d\n",(*it).p.x,(*it_signal).p.x);
							(*it).run(*it_signal);//printf("end\n");
						} else {
							std::vector<Car_agent>::iterator it2 = it;
							++it2;
							if((*it2).p.x < (*it_signal).p.x) {
//								printf("4pos=%d,signalpos=%d\n",(*it).p.x,(*it_signal).p.x);
								(*it).run(*it_signal);
							} else {
//								printf("5pos=%d,other=%d\n",(*it).p.x,(*it2).p.x);
								(*it).run(*it2);
							}
						}
					}
				}
			}
			for(std::vector<Car_agent>::iterator it=agent.at(side).begin();it!=agent.at(side).end();) {
				if(abs((*it).get_initial_pos() - (*it).p.x) >= line.at(side).getLength()) {
					//printf("add_car_count initialpos=%d pos=%d\n", (*it).get_initial_pos(),(*it).p.x);
					line.at(side).add_car_count();
//					printf("RIGHT=%d, LEFT=%d\n",line.at(0).get_car_count(),line.at(1).get_car_count());
					it = agent.at(side).erase( it );
					if(agent.at(side).empty()){
						//printf("break");
						break;
					}
				  } else {
				    ++it;
				  }			}
			//printf("run once %d\n",side);

		}
	}
}

//void Map::addsignal(Signal s) {
//	signal.push_back(s);
//}
//
//std::vector<Car_agent> Map::getCar_agent_vector(SIDE s) {
//		return agent.at((int)s);
//}
//
//Line Map::getLine(SIDE s) {
//	return line.at((int)s);
//}

void Map::writefile() {
	std::ofstream ofs;
	ofs.open( "map.txt" , std::ios::out | std::ios::app);
	for(int side=0;side<(int)MAX_SIDE;side++) {
		for(std::vector<Car_agent>::iterator it=agent.at(side).begin();it!=agent.at(side).end();++it) {
			if((*it).p.x > 0 && (*it).p.x < m_mapparameter.line_lenght) {
				ofs << "a," << side << "," << (*it).p.x << ","<< (*it).velocity << ",";// << std::endl;
			}
		}
	}
	for(std::vector<Signal>::iterator it=signal.begin();it!=signal.end();++it) {
		std::vector<Signal>::iterator it2 = it;
		if(++it2==signal.end()){
			ofs << "s," << (*it).signal_is_green() << "," << (*it).p.x;
		} else {
			ofs << "s," << (*it).signal_is_green() << "," << (*it).p.x << ",";
		}
	}
	ofs << std::endl;
	ofs.close();
}

void Map::show() {
	for(int side=0;side<(int)MAX_SIDE;side++) {
		for(std::vector<Car_agent>::iterator it=agent.at(side).begin();it!=agent.at(side).end();++it) {
			printf("(%d,%d),",(*it).p.x, (*it).velocity);
		}
		printf("\n");
	}
}
