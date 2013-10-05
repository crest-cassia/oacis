#include <stdlib.h>
#include <mpi.h>
#include <sstream>
#include <string>
#include <fstream>
#include <json/json.h>
#include <json/writer.h>
#include <json/reader.h>

using namespace std;

int main(int argc, char** argv) {
  ifstream ifs( "_input.json" );
  string input;
  getline(ifs, input);
  ifs.close();
  Json::Reader	reader;
  Json::Value	j;
  reader.parse ( input, j );

  int n, myid, numprocs;
  MPI_Init(&argc,&argv);
  MPI_Comm_size(MPI_COMM_WORLD, &numprocs);
  MPI_Comm_rank(MPI_COMM_WORLD, &myid);
  if(myid < j ["runs"].size()) {
    string run_id = j["runs"][static_cast<unsigned int>(myid)]["id"].asString();
    string command = "mkdir " + run_id;
    system(command.c_str());
    string exec_command = j["command"].asString();
    command = "cd "+run_id+";"+exec_command;
    ofstream ofs((run_id+"/_input.json").c_str());
    Json::StyledWriter writer;//書き込みたい場合
    ofs << writer.write( j["runs"][static_cast<unsigned int>(myid)] );
    ofs.close();
    system(command.c_str());
  }
  MPI_Finalize();
  return 0;
}
