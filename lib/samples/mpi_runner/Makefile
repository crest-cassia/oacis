JSONCPP_DIR=~/jsoncpp-src-0.5.0
JSONCPP_lib_DIR=$(JSONCPP_DIR)/buildscons/linux-gcc-4.6/src/lib_json
JSONCPP_inc_DIR=$(JSONCPP_DIR)/include

CXX=mpiFCCpx

TARGET=mpi_parallel_for_runs

SRC=$(TARGET).cpp
all:$(TARGET)

mpi_parallel_for_runs:
	$(CXX) -I $(JSONCPP_inc_DIR) -o $(TARGET) $(SRC) $(JSONCPP_lib_DIR)/*.o
clean:
	rm $(TARGET)
	rm *.o
