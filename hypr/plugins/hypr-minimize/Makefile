CXX      ?= c++
PLUGIN    = hypr-minimize.so
SRC       = main.cpp
CXXFLAGS += -shared -fPIC -std=c++26 -DWLR_USE_UNSTABLE -O2
CXXFLAGS += $(shell pkg-config --cflags hyprland pixman-1 libdrm hyprutils)

.PHONY: all clean
all: $(PLUGIN)

$(PLUGIN): $(SRC)
	$(CXX) $(CXXFLAGS) -o $@ $<

clean:
	rm -f $(PLUGIN)
