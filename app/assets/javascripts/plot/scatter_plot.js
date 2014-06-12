function ScatterPlot() {
  Plot.call(this);// call constructor of Plot
}

ScatterPlot.prototype = Object.create(Plot.prototype);// ScatterPlot is sub class of Plot
ScatterPlot.prototype.constructor = ScatterPlot;// override constructor

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
      break;
  }
  this.xScale = scale;
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
      break;
  }
  this.yScale = scale;
};

ScatterPlot.prototype.AddPlot = function() {
  var plot = this;

  var result_min_val = d3.min( this.data.data, function(d) { return d[1];});
  var result_max_val = d3.max( this.data.data, function(d) { return d[1];});
  var colorScale = d3.scale.linear().range(["#0041ff", "#ffffff", "#ff2800"]);
  var colorScalePoint = d3.scale.linear().range(["#0041ff", "#888888", "#ff2800"]);
  colorScale.domain([ result_min_val, (result_min_val+result_max_val)/2.0, result_max_val]).nice();
  colorScalePoint.domain( colorScale.domain() ).nice();

  function add_color_map_group() {
    var color_map = plot.svg.append("g")
      .attr({
        "transform": "translate(" + plot.width + "," + plot.margin.top + ")",
        "id": "color-map-group"
      });
    var scale = d3.scale.linear().domain([0.0, 0.5, 1.0]).range(colorScale.range());
    color_map.append("text")
      .attr({x: 10.0, y: 20.0, dx: "0.1em", dy: "-0.4em"})
      .style("text-anchor", "begin")
      .text("Result");
    color_map.selectAll("rect")
      .data([1.0, 0.8, 0.6, 0.4, 0.2, 0.0])
      .enter().append("rect")
      .attr({
        x: 10.0,
        y: function(d,i) { return i * 20.0 + 20.0; },
        width: 19,
        height: 19,
        fill: function(d) { return scale(d); }
      });
    color_map.append("text")
      .attr({x: 30.0, y: 40.0, dx: "0.2em", dy: "-0.3em"})
      .style("text-anchor", "begin")
      .text( colorScale.domain()[2] );
    color_map.append("text")
      .attr({x: 30.0, y: 140.0, dx: "0.2em", dy: "-0.3em"})
      .style("text-anchor", "begin")
      .text( colorScale.domain()[0] );
  }
  add_color_map_group();

  function add_voronoi_group() {
    var voronoi_group = plot.svg.append("g")
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
    var point = plot.svg.append("g")
      .attr("id", "point-group");
    point.selectAll("circle")
      .data(mapped)
      .enter()
        .append("circle")
        .attr("clip-path", "url(#clip)")
        .style("fill", function(d) { return colorScalePoint(d.average);})
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

  function update_voronoi_group() {
    var result_min_val = d3.min( plot.data.data, function(d) { return d[1];});
    var result_max_val = d3.max( plot.data.data, function(d) { return d[1];});
    var colorScale = d3.scale.linear().range(["#0041ff", "#ffffff", "#ff2800"]);
    colorScale.domain([ result_min_val, (result_min_val+result_max_val)/2.0, result_max_val]).nice();
    var voronoi = plot.svg.select("g#voronoi-group");
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
          .style("fill", function(d, i) { return colorScale(filtered_data[i][1]);})
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
    var point = plot.svg.select("g#point-group");
    point.selectAll("circle")
      .attr("r", function(d) { return (d.psid == plot.current_ps_id) ? 5 : 3;})
      .attr("cx", function(d) { return plot.xScale(d.x);})
      .attr("cy", function(d) { return plot.yScale(d.y);});
  }
  update_point_group();
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
    plot.description.append("a").attr({target: "_blank", href: this.url}).text("show data in json");
    plot.description.append("br");
    plot.description.append("a").text("delete plot").on("click", function() {
      plot.Destructor();
    });

    plot.description.append("br");
    plot.description.append("br").style("line-height", "400%");
    plot.description.append("input").attr("type", "checkbox").on("change", function() {
      var new_scale;
      if(this.checked) {
        new_scale = "log";
      } else {
        new_scale = "linear";
      }
      plot.SetXScale(new_scale);
      plot.xAxis.scale(plot.xScale);
      plot.UpdatePlot();
      plot.UpdateAxis();
    });
    plot.description.append("span").html("log scale on x axis");
    plot.description.append("br");

    plot.description.append("input").attr("type", "checkbox").on("change", function() {
      var new_scale;
      if(this.checked) {
        new_scale = "log";
      } else {
        new_scale = "linear";
      }
      plot.SetYScale(new_scale);
      plot.yAxis.scale(plot.yScale);
      plot.UpdatePlot();
      plot.UpdateAxis();
    });
    plot.description.append("span").html("log scale on y axis");
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
  var progress = show_loading_spin_arc(plot.svg, plot.width, plot.height);

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

