require 'spec_helper'

describe MatplotlibUtil do

  describe ".script_for_single_line_plot" do

    it "returns a gnuplot script to draw a single line plot" do
      data = [[0,1,0.1], [1,2,0.2]]
      expected = <<-EOS
# %%
import numpy as np
import matplotlib.pyplot as plt

plt.xlabel("XXX")
plt.ylabel("YYY")

x = [0, 1]
y = [1, 2]

plt.plot(x, y)
plt.show()
EOS
      expect(MatplotlibUtil.script_for_single_line_plot(data, "XXX", "YYY")).to eq expected
    end

    it "returns a script to draw a single line plot with errorbars when option is given" do
      data = [[0,1,0.1], [1,2,0.2]]
      expected = <<-EOS
# %%
import numpy as np
import matplotlib.pyplot as plt

plt.xlabel("XXX")
plt.ylabel("YYY")

x = [0, 1]
y = [1, 2]
yerr = [0.1, 0.2]

plt.errorbar(x, y, yerr=yerr)
plt.show()
EOS
      expect(MatplotlibUtil.script_for_single_line_plot(data, "XXX", "YYY", true)).to eq expected
    end

    it "plots correctly even when third column is nil" do
      data = [[0,1,0.1,"aaa"], [1,2,nil,"bbb"]]
      expected = <<-EOS
# %%
import numpy as np
import matplotlib.pyplot as plt

plt.xlabel("XXX")
plt.ylabel("YYY")

x = [0, 1]
y = [1, 2]
yerr = [0.1, 0.0]

plt.errorbar(x, y, yerr=yerr)
plt.show()
EOS
      expect(MatplotlibUtil.script_for_single_line_plot(data, "XXX", "YYY", true)).to eq expected
    end
  end

  describe ".script_for_multi_line_plot" do

    it "returns a gnuplot script to draw a series of plots" do
      data_arr = [
        [[0,1,0.1], [1,2,0.2]],
        [[0,3,0.3], [1,4,0.4]]
      ]
      expected = <<-EOS
# %%
import numpy as np
import matplotlib.pyplot as plt

plt.xlabel("XXX")
plt.ylabel("YYY")

# ZZZ = 5
label = 'ZZZ=5'
x = [0, 1]
y = [1, 2]

plt.plot(x, y, label=label)

# ZZZ = 4
label = 'ZZZ=4'
x = [0, 1]
y = [3, 4]

plt.plot(x, y, label=label)

plt.legend()
plt.show()
      EOS
      expect(MatplotlibUtil.script_for_multi_line_plot(data_arr, "XXX", "YYY", false, "ZZZ", [5, 4])).to eq expected
    end

    it "returns a gnuplot script to draw a series of plots with errorbars when option is given" do
      data_arr = [
        [[0,1,0.1], [1,2,0.2]],
        [[0,3,0.3], [1,4,0.4]]
      ]
      expected = <<-EOS
# %%
import numpy as np
import matplotlib.pyplot as plt

plt.xlabel("XXX")
plt.ylabel("YYY")

# ZZZ = 5
label = 'ZZZ=5'
x = [0, 1]
y = [1, 2]
yerr = [0.1, 0.2]

plt.errorbar(x, y, yerr=yerr, label=label)

# ZZZ = 4
label = 'ZZZ=4'
x = [0, 1]
y = [3, 4]
yerr = [0.3, 0.4]

plt.errorbar(x, y, yerr=yerr, label=label)

plt.legend()
plt.show()
      EOS
      expect(MatplotlibUtil.script_for_multi_line_plot(data_arr, "XXX", "YYY", true, "ZZZ", [5, 4])).to eq expected
    end
  end

  describe ".script_for_3d_scatter_plot" do

    it "returns a script to plot 3d scatter plot" do
      data_arr = [
        [{"param_1" => 1.0, "param_2" => 2.0, "other_param" => 3.0}, 3.0, 0.001, "PSID1"],
        [{"param_1" => 4.0, "param_2" => 5.0, "other_param" => 6.0}, 7.0, 0.001, "PSID2"]
      ]
      expected = <<-EOS
# %%
import numpy as np
import matplotlib.pyplot as plt

fig = plt.figure()
ax = fig.add_subplot(projection='3d')

ax.set_xlabel("param_1")
ax.set_ylabel("param_2")
ax.set_zlabel("z_label")

x = [1.0, 4.0]
y = [2.0, 5.0]
z = [3.0, 7.0]
ax.scatter(x, y, z)
plt.show()
      EOS

      expect(MatplotlibUtil.script_for_3d_scatter_plot(data_arr, "param_1", "param_2", "z_label")).to eq expected
    end

  end
end
