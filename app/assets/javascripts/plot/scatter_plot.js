function ScatterPlot() {
  Plot.call(this);// call constructor of Plot
  this.colorScale = d3.scale.linear().range(["#0041ff", "#ffffff", "#ff2800"]);
  this.colorScalePoint = d3.scale.linear().range(["#0041ff", "#888888", "#ff2800"]);
}

ScatterPlot.prototype = Object.create(Plot.prototype);// ScatterPlot is sub class of Plot
ScatterPlot.prototype.constructor = ScatterPlot;// override constructor
ScatterPlot.prototype.IsLog = [false, false];   // true if x/y scale is log

ScatterPlot.prototype.SetXScale = function(xscale) {
  var plot = this;
  var scale = null, min, max;
  switch(xscale) {
  case "linear":
    scale = d3.scale.linear().range([0, this.width]);
    min = d3.min( this.data.data, function(r) { return r[0][plot.data.xlabel];});
    max = d3.max( this.data.data, function(r) { return r[0][plot.data.xlabel];});
    scale.domain([
      min,
      max
    ]).nice();
    plot.IsLog[0] = false;
    break;
  case "log":
    var data_in_logscale = this.data.data.filter(function(element, index, array) {
      return element[0][plot.data.xlabel] > 0.0;
    });
    scale = d3.scale.log().clamp(true).range([0, this.width]);
    min = d3.min( data_in_logscale, function(r) { return r[0][plot.data.xlabel];});
    max = d3.max( data_in_logscale, function(r) { return r[0][plot.data.xlabel];});
    scale.domain([
      (!min || min<0.0) ? 0.1 : min,
      (!max || max<0.0) ? 1.0 : max
    ]).nice();
    plot.IsLog[0] = true;
    break;
  }
  this.xScale = scale;
  this.xAxis.scale(this.xScale);
};

ScatterPlot.prototype.SetYScale = function(yscale) {
  var plot = this;
  var scale = null, min, max;
  switch(yscale) {
  case "linear":
    scale = d3.scale.linear().range([this.height, 0]);
    min = d3.min( this.data.data, function(r) { return r[0][plot.data.ylabel];});
    max = d3.max( this.data.data, function(r) { return r[0][plot.data.ylabel];});
    scale.domain([
      min,
      max
    ]).nice();
    plot.IsLog[1] = false;
    break;
  case "log":
    var data_in_logscale = this.data.data.filter(function(element, index, array) {
      return element[0][plot.data.ylabel] > 0.0;
    });
    scale = d3.scale.log().clamp(true).range([this.height, 0]);
    min = d3.min( data_in_logscale, function(r) { return r[0][plot.data.ylabel];});
    max = d3.max( data_in_logscale, function(r) { return r[0][plot.data.ylabel];});
    scale.domain([
      (!min || min<0.0) ? 0.1 : min,
      (!max || max<0.0) ? 1.0 : max
    ]).nice();
    plot.IsLog[1] = true;
    break;
  }
  this.yScale = scale;
  this.yAxis.scale(this.yScale);
};

ScatterPlot.prototype.SetXDomain = function(xmin, xmax) {
  var plot = this;
  if( plot.IsLog[0] ) {
    if( xmin <= 0.0 ) {
      plot.SetXScale("log"); // call this to calculate auto-domain
      xmin = plot.xScale.domain()[0];
      if( xmax <= 0.0 ) {
        xmax = xmin + 0.000001;
      }
    }
  }
  plot.xScale.domain([xmin, xmax]);
};

ScatterPlot.prototype.SetYDomain = function(ymin, ymax) {
  var plot = this;
  if( plot.IsLog[1] ) {
    if( ymin <= 0.0 ) {
      plot.SetYScale("log"); // call this to calculate auto-domain
      ymin = plot.yScale.domain()[0];
      if( ymax <= 0.0 ) {
        ymax = ymin + 0.000001;
      }
    }
  }
  plot.yScale.domain([ymin, ymax]);
};

ScatterPlot.prototype.AddPlot = function() {
  var plot = this;

  var result_min_val = d3.min( this.data.data, function(d) { return d[1];});
  var result_max_val = d3.max( this.data.data, function(d) { return d[1];});
  this.colorScale.domain([ result_min_val, (result_min_val+result_max_val)/2.0, result_max_val]).nice();
  this.colorScalePoint.domain( this.colorScale.domain() ).nice();

  function add_color_map_group() {
    var color_map = plot.main_group.append("g")
      .attr({
        "transform": "translate(" + plot.width + "," + plot.margin.top + ")",
        "id": "color-map-group"
      });
    var scale = d3.scale.linear().domain([0.0, 0.5, 1.0]).range(plot.colorScale.range());
    color_map.append("text")
      .attr({x: 10.0, y: 20.0, dx: "0.1em", dy: "-0.4em"})
      .style("text-anchor", "begin")
      .text("Result");
    color_map.selectAll("rect")
      .data([1.0, 0.8, 0.6, 0.5, 0.4, 0.2, 0.0])
      .enter().append("rect")
      .attr({
        x: 10.0,
        y: function(d,i) { return i * 20.0 + 20.0; },
        width: 19,
        height: 19,
        fill: function(d) { return scale(d); }
      });
    color_map.append("text")
      .attr({id:"result-range-max", x: 30.0, y: 40.0, dx: "0.2em", dy: "-0.3em"})
      .style("text-anchor", "begin")
      .text( plot.colorScale.domain()[2] );
    color_map.append("text")
      .attr({id:"result-range-middle", x: 30.0, y: 100.0, dx: "0.2em", dy: "-0.3em"})
      .style("text-anchor", "begin")
      .text( plot.colorScale.domain()[1] );
    color_map.append("text")
      .attr({id:"result-range-min", x: 30.0, y: 160.0, dx: "0.2em", dy: "-0.3em"})
      .style("text-anchor", "begin")
      .text( plot.colorScale.domain()[0] );
  }
  add_color_map_group();

  var plot_group = plot.main_group.append("g").attr("id", "plot-group");

  function add_voronoi_group() {
    var voronoi_group = plot_group.append("g")
      .attr("id", "voronoi-group");
  }
  add_voronoi_group();

  function add_point_group() {
    var tooltip = d3.select("#plot-tooltip");
    var mapped = plot.data.data.map(function(v) {
      return {
        x: v[0][plot.data.xlabel], y: v[0][plot.data.ylabel],
        average: v[1], error: v[2], psid: v[3]
      };
    });
    var point = plot_group.append("g")
      .attr("id", "point-group");
    point.selectAll("circle")
      .data(mapped)
      .enter()
        .append("circle")
        .attr("clip-path", "url(#clip)")
        .style("fill", function(d) { return plot.colorScalePoint(d.average);})
        .on("mouseover", function(d) {
          tooltip.transition()
            .duration(200)
            .style("opacity", 0.8);
          tooltip.html(
            plot.data.xlabel + " : " + d.x + "<br/>" +
            plot.data.ylabel + " : " + d.y + "<br/>" +
            "Result : " + Math.round(d.average*1000000)/1000000 +
            " (" + Math.round(d.error*1000000)/1000000 + ")<br/>" +
            "ID: " + d.psid);
        })
        .on("mousemove", function() {
          tooltip
            .style("top", (d3.event.pageY-10) + "px")
            .style("left", (d3.event.pageX+10) + "px");
        })
        .on("mouseout", function() {
          tooltip.transition()
            .duration(300)
            .style("opacity", 0);
        })
        .on("dblclick", function(d) {
          // open a link in a background window
          window.open(plot.parameter_set_base_url + d.psid, '_blank');
        });
  }
  add_point_group();

  this.UpdatePlot();
};

ScatterPlot.prototype.UpdatePlot = function() {
  var plot = this;

  function update_color_scale() {
    var scale = d3.scale.linear().domain([0.0, 0.5, 1.0]).range(plot.colorScale.range());
    plot.main_group.select("g#color-map-group").selectAll("rect")
      .attr("fill", function(d) { return scale(d); });

    plot.main_group.select("#result-range-max")
      .text( plot.colorScale.domain()[2] );
    plot.main_group.select("#result-range-middle")
      .text( plot.colorScale.domain()[1] );
    plot.main_group.select("#result-range-min")
      .text( plot.colorScale.domain()[0] );

    plot.main_group.selectAll("circle")
      .style("fill", function(d) { return plot.colorScalePoint(d.average);});
  }
  update_color_scale();

  function update_voronoi_group() {
    var result_min_val = d3.min( plot.data.data, function(d) { return d[1];});
    var result_max_val = d3.max( plot.data.data, function(d) { return d[1];});
    var voronoi = plot.main_group.select("g#voronoi-group");
    var d3voronoi = d3.geom.voronoi()
      .clipExtent([[0, 0], [plot.width, plot.height]]);
    var filtered_data = plot.data.data.filter(function(v) {
      var x = v[0][plot.data.xlabel];
      var y = v[0][plot.data.ylabel];
      var xdomain = plot.xScale.domain();
      var ydomain = plot.yScale.domain();
      return (x >= xdomain[0] && x <= xdomain[1] && y >= ydomain[0] && y <= ydomain[1]);
    });
    var vertices = filtered_data.map(function(v) {
      return [
        plot.xScale(v[0][plot.data.xlabel]) + Math.random() * 1.0 - 0.5, // noise size 1.0 is a good value
        plot.yScale(v[0][plot.data.ylabel]) + Math.random() * 1.0 - 0.5
      ];
    });

    function draw_voronoi_heat_map() {
      // add noise to coordinates of vertices in order to prevent hang-up.
      // hanging-up sometimes happen when duplicated points are included.
      var path = voronoi.selectAll("path")
        .data(d3voronoi(vertices))
        .enter()
          .append("path")
          .attr("fill", function(d, i) {
            if(filtered_data[i][1] < plot.colorScale.domain()[0]) {return "url(#TrianglePattern)";}
            if(filtered_data[i][1] > plot.colorScale.domain()[2]) {return "url(#TrianglePattern)";}
            return plot.colorScale(filtered_data[i][1]);
          })
          .attr("d", function(d) { return "M" + d.join('L') + "Z"; })
          .style("fill-opacity", 0.7)
          .style("stroke", "none");
    }
    try {
      voronoi.selectAll("path").remove();
      draw_voronoi_heat_map();
      // Voronoi division fails when duplicate points are included.
      // In that case, just ignore creating voronoi heatmap and continue plotting.
    } catch(e) {
      console.log(e);
    }
  }
  update_voronoi_group();

  function update_point_group() {
    var point = plot.main_group.select("g#point-group");
    point.selectAll("circle")
      .attr("r", function(d) { return (d.psid == plot.current_ps_id) ? 5 : 3;})
      .attr("cx", function(d) { return plot.xScale(d.x);})
      .attr("cy", function(d) { return plot.yScale(d.y);});
  }
  update_point_group();

  this.UpdateAxis();
};

ScatterPlot.prototype.AddDescription = function() {
  var plot = this;

  // description for the specification of the plot
  function add_label_table() {
  var dl = plot.description.append("dl");
    dl.append("dt").text("X-Axis");
    dl.append("dd").text(plot.data.xlabel);
    dl.append("dt").text("Y-Axis");
    dl.append("dd").text(plot.data.ylabel);
    dl.append("dt").text("Result");
    dl.append("dd").text(plot.data.result);
  }
  add_label_table();

  function add_tools() {
    plot.description.append("a").attr({target: "_blank", href: plot.url}).text("show data in json");
    plot.description.append("br");
    var downloadAsFile = function(fileName, content) {
      var blob = new Blob([content]);
      var url = window.URL || window.webkitURL;
      var blobURL = url.createObjectURL(blob);
      var a = document.createElement('a');
      a.download = fileName;
      a.href = blobURL;
      return a;
    };
    var a_link = downloadAsFile("scatter_plot.svg", $(plot.svg.node()).parent().html());
    $(a_link).text("download svg");
    plot.description.node().appendChild(a_link);
    plot.description.append("br");
    plot.description.append("a").text("delete plot").style('cursor','pointer').on("click", function() {
      plot.Destructor();
    });

    plot.description.append("br");
    plot.description.append("br").style("line-height", "400%");
    plot.description.append("input").attr("type", "checkbox").on("change", function() {
      plot.SetXScale(this.checked ? "log" : "linear");
      plot.SetYScale(plot.IsLog[1] ? "log" : "linear"); // reset xScale domain to draw non expanded plot
      plot.UpdatePlot();
      while (control_plot.node().firstChild) {
        control_plot.node().removeChild(control_plot.node().firstChild);
      }
      add_brush();
    });
    plot.description.append("span").html("log scale on x axis");
    plot.description.append("br");

    plot.description.append("input").attr("type", "checkbox").on("change", function() {
      plot.SetXScale(plot.IsLog[0] ? "log" : "linear"); // reset xScale domain to draw non expanded plot
      plot.SetYScale(this.checked ? "log" : "linear");
      plot.UpdatePlot();
      while (control_plot.node().firstChild) {
        control_plot.node().removeChild(control_plot.node().firstChild);
      }
      add_brush();
    });
    plot.description.append("span").html("log scale on y axis");

    plot.description.append("br");
    var control_plot = plot.description.append("div").style("margin-top", "10px");
    function add_brush() {
      var clone = plot.main_group.select("g#plot-group").node().cloneNode(true);
      control_plot.append("svg")
        .attr("width","210")
        .attr("height","155")
        .attr("viewBox","0 0 574 473")
        .node().appendChild(clone);

      var x = plot.IsLog[0] ? d3.scale.log() : d3.scale.linear();
      x.range([0, plot.width]);
      x.domain(plot.xScale.domain());
      var x_min = x.domain()[0];
      var x_max = x.domain()[1];

      var y = plot.IsLog[1] ? d3.scale.log() : d3.scale.linear();
      y.range([plot.height, 0]);
      y.domain(plot.yScale.domain());
      var y_min = y.domain()[0];
      var y_max = y.domain()[1];

      var brush = d3.svg.brush()
        .x(x)
        .y(y)
        .on("brush", brushed);

      var cloned_main_group = d3.select(clone)
        .attr("transform", "translate(5,5)");
      var line_shape = "M0,0V" + plot.height + "H" + plot.width;
      cloned_main_group.append("path").attr("d", line_shape)
        .style({
          "fill": "none",
          "stroke": "#000",
          "shape-rendering": "crispEdges"
        });

      cloned_main_group.append("g")
        .attr("class", "brush")
        .call(brush)
        .selectAll("rect")
        .style({"stroke": "orange", "stroke-width": 4, "fill-opacity": 0.125, "shape-rendering": "crispEdges"});

      function brushed() {
        var domain = brush.empty() ? [[x_min,y_min],[x_max, y_max]] : brush.extent();
        plot.SetXDomain(domain[0][0], domain[1][0]);
        plot.SetYDomain(domain[0][1], domain[1][1]);
        plot.UpdatePlot();
        plot.UpdateAxis();
      }
    }
    add_brush();

    function add_result_scale_controller() {
      var pattern = plot.main_group.select("defs").append("pattern");
      pattern
        .attr("id", "TrianglePattern")
        .attr("patternUnits", "userSpaceOnUse")
        .attr("x", 0)
        .attr("y", 0)
        .attr("width", 4)
        .attr("height", 4);
      pattern.append("rect")
        .attr("x", 1)
        .attr("y", 1)
        .attr("width", 2)
        .attr("height", 2)
        .attr("fill", "black");

      plot.description.append("br");
      plot.description.append("div").text("Result range :");
      var table = plot.description.append("table");
      var tr = table.append("tr");
      tr.append("td").text("Max.");
      tr.append("td").append("input").attr("type", "text").attr("id", "range-max");
      tr = table.append("tr");
      tr.append("td").text("Mid.");
      tr.append("td").append("input").attr("type", "text").attr("id", "range-mid");
      tr = table.append("tr");
      tr.append("td").text("Min.");
      tr.append("td").append("input").attr("type", "text").attr("id", "range-min");

      var range_change = function(key, text_field) {
        var domain = plot.colorScale.domain();
        var index_table = {"max": 2, "mid": 1, "min": 0};
        try{
          if(isNaN(domain[index_table[key]])) {
            alert("Do not change tha value \"NaN\"");
            text_field.value=""+domain[index_table[key]];
            return;
          }
          if(isNaN(Number(text_field.value))) {
            alert(text_field.value + " is not a number");
            text_field.value=""+domain[index_table[key]];
          } else if(key == "max" && Number(text_field.value) < domain[1] ) {
            alert(text_field.value + " is not greater than or equal to range mid. value");
            text_field.value=""+domain[2];
          } else if(key == "mid" && Number(text_field.value) < domain[0] ) {
            alert(text_field.value + " is not greater than or equal to range min. value");
            text_field.value=""+domain[1];
          } else if(key == "mid" && Number(text_field.value) > domain[2] ) {
            alert(text_field.value + " is not less than or equal to range max. value");
            text_field.value=""+domain[1];
          } else if(key == "min" && Number(text_field.value) > domain[1] ) {
            alert(text_field.value + " is not less than or equal to range mid. value");
            text_field.value=""+domain[0];
          } else {
            domain[index_table[key]] = Number(text_field.value);
            plot.colorScale.domain(domain);
            plot.colorScalePoint.domain(domain);
            plot.SetXScale(plot.IsLog[0] ? "log" : "linear"); // reset xScale domain to draw non expanded plot
            plot.SetYScale(plot.IsLog[1] ? "log" : "linear"); // reset xScale domain to draw non expanded plot
            plot.UpdatePlot();
            while (control_plot.node().firstChild) {
              control_plot.node().removeChild(control_plot.node().firstChild);
            }
            add_brush();
          }
        } catch(e) {
          alert(e);
        }
      };
      plot.description.select("#range-max")
        .attr("value", plot.colorScale.domain()[2])
        .on("change", function() {
          range_change("max", this);
        });
      plot.description.select("#range-mid")
        .attr("value", plot.colorScale.domain()[1])
        .on("change", function() {
          range_change("mid", this);
        });
      plot.description.select("#range-min")
        .attr("value", plot.colorScale.domain()[0])
        .on("change", function() {
          range_change("min", this);
        });
    }
    add_result_scale_controller();
  }
  add_tools();

};

ScatterPlot.prototype.Draw = function() {
  this.AddPlot();
  this.AddAxis();
  this.AddDescription();
};

function draw_scatter_plot(url, parameter_set_base_url, current_ps_id) {
  var plot = new ScatterPlot();
  var progress = show_loading_spin_arc(plot.main_group, plot.width, plot.height);

  var xhr = d3.json(url)
    .on("load", function(dat) {
      progress.remove();
      plot.Init(dat, url, parameter_set_base_url, current_ps_id);
      plot.Draw();
    })
  .on("error", function() {progress.remove();})
  .get();
  progress.on("mousedown", function(){
    xhr.abort();
    plot.Destructor();
  });
}
