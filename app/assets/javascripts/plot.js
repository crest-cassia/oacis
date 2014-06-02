function Plot() {
  this.row = d3.select("#plot").insert("div","div").attr("class", "row");
  this.plot_region = this.row.append("div").attr("class", "span8");
  this.description = this.row.append("div").attr("class", "span4");
  this.svg = this.plot_region.insert("svg")
    .attr({
      "width": this.width + this.margin.left + this.margin.right,
      "height": this.height + this.margin.top + this.margin.bottom
    })
    .append("g")
      .attr("transform", "translate(" + this.margin.left + "," + this.margin.top + ")");
}

Plot.prototype.margin = {top: 10, right: 100, bottom: 100, left: 100};
Plot.prototype.width = 560;
Plot.prototype.height = 460;
Plot.prototype.data = null;
Plot.prototype.url = null;
Plot.prototype.current_ps_id = null;
Plot.prototype.parameter_set_base_url = null;

Plot.prototype.Destructor = function() { this.row.remove(); };

function LinePlot() {
  Plot.call(this);// call constructor of Plot
}

LinePlot.prototype = Object.create(Plot.prototype);// LinePlot is sub class of Plot
LinePlot.prototype.constructor = LinePlot;// override constructor
LinePlot.prototype.data = null;
LinePlot.prototype.xScale = null;
LinePlot.prototype.yScale = null;
LinePlot.prototype.xAxis = null;
LinePlot.prototype.yAxis = null;
LinePlot.prototype.colorScale = null;

LinePlot.prototype.Init = function(data, url, parameter_set_base_url, current_ps_id) {
  this.data = data;
  this.url = url;
  this.parameter_set_base_url = parameter_set_base_url;
  this.current_ps_id = current_ps_id;

  this.SetXScale("linear");
  this.SetYScale("linear");
  this.xAxis = d3.svg.axis().scale(this.xScale).orient("bottom");
  this.yAxis = d3.svg.axis().scale(this.yScale).orient("left");
  this.colorScale = d3.scale.category10();
};

LinePlot.prototype.SetXScale = function(xscale) {
  var scale = null;
  switch(xscale) {
    case "linear":
      scale = d3.scale.linear().range([0, this.width]);
      scale.domain([
        d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[0];})}),
        d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[0];})})
      ]).nice();
      break;
    case "log":
      scale = d3.scale.log().clamp(true).range([0, this.width]);
      var min = d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[0];})})
      scale.domain([
        (min<0.1 ? 0.1 : min),
        d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[0];})})
      ]).nice();
      break;
    default: // undefined
      scale = d3.scale.linear().range([0, this.width]);
      console.log(xscale + "is not defined as scale. Set linear scale for x-axis.");
      scale.domain([
        d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[0];})}),
        d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[0];})})
      ]).nice();
      break;
  }
  this.xScale = scale;
};

LinePlot.prototype.SetYScale = function(yscale) {
  var scale = null;
  switch(yscale) {
    case "linear":
      scale = d3.scale.linear().range([this.height, 0]);
      scale.domain([
        d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[1] - v[2];}) }),
        d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[1] + v[2];}) })
      ]).nice();
      break;
    case "log":
      scale = d3.scale.log().clamp(true).range([this.height, 0]);
      var min = d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[1] - v[2];})})
      scale.domain([
        (min<0.1 ? 0.1 : min),
        d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[1] + v[2];})})
      ]).nice();
      break;
    default: // undefined
      console.log(scale + "is not defined as scale. Set linear scale for y-axis.");
      scale = d3.scale.linear().range([this.height, 0]);
      scale.domain([
        d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[1] - v[2];}) }),
        d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[1] + v[2];}) })
      ]).nice();
      break;
  }
  this.yScale = scale;
};

LinePlot.prototype.AddAxis = function() {
  // X-Axis
  this.svg.append("g")
    .attr("class", "x axis")
    .attr("transform", "translate(0," + this.height + ")")
    .append("text")
      .style("text-anchor", "middle")
      .attr("x", this.width / 2.0)
      .attr("y", 50.0)
      .text(this.data.xlabel);

  // Y-Axis
  this.svg.append("g")
      .attr("class", "y axis")
    .append("text")
      .attr("transform", "rotate(-90)")
      .attr("x", -this.height/2)
      .attr("y", -50.0)
      .style("text-anchor", "middle")
      .text(this.data.ylabel);

  this.UpdateAxis();
};

LinePlot.prototype.UpdateAxis = function() {
  this.svg.select(".x.axis").call(this.xAxis);
  this.svg.select(".y.axis").call(this.yAxis);
}

LinePlot.prototype.AddPlot = function() {
    var plot = this;
    // group for each series
    var series = this.svg
      .selectAll(".series")
      .data(this.data.data)
      .enter().append("g")
        .attr("class", "series");
    series.append("path")
      .attr("class", "line")
      .style({
        "stroke": function(d, i) { return plot.colorScale(i);},
        "fill": "none",
        "stroke-width": "1.5px"
      });

    // draw circles
    var tooltip = d3.select("#plot-tooltip");
    var point = series.selectAll("circle")
      .data(function(d,i) {
        return d.map(function(v) {
          return {
            x: v[0], y: v[1], yerror: v[2],
            series_index: i, series_value: plot.data.series_values[i], psid: v[3]
          };
        });
      }).enter();
    point.append("circle")
      .style("fill", function(d) { return plot.colorScale(d.series_index);})
      .attr("r", function(d) { return (d.psid == plot.current_ps_id) ? 5 : 3;})
      .on("mouseover", function(d) {
        tooltip.transition()
          .duration(200)
          .style("opacity", .8);
        tooltip.html(
          plot.data.xlabel + " : " + d.x + "<br/>" +
          plot.data.ylabel + " : " + Math.round(d.y*1000000)/1000000 +
          " (" + Math.round(d.yerror*1000000)/1000000 + ")<br/>" +
          (plot.data.series ? (plot.data.series + " : " + d.series_value + "<br/>") : "") +
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

    // draw error bar
    point.insert("line", "circle")
      .attr("class", "line yerror bar");
    point.insert("line", "circle")
      .attr("class", "line yerror top");
    point.insert("line", "circle")
      .attr("class", "line yerror bottom");

    // draw legend
    var legend = this.svg.append("g")
      .attr("class", "legend")
      .attr("transform", "translate(" + this.width + "," + 20 + ")");
    var legendItem = legend.selectAll("g")
      .data(this.data.series_values)
      .enter().append("g")
      .attr("class", "legend-item")
      .attr("transform", function(d,i) {
        return "translate(10," + (i*20) + ")";
      });

    // draw legend title
    this.svg.append("text")
      .attr({
        x: this.width,
        y: 0,
        dx: ".8em",
        dy: ".8em"
      })
      .text(this.data.series);
    legendItem.append("rect")
      .attr("width", 15)
      .attr("height", 15)
      .style("fill", function(d,i) { return plot.colorScale(i);});
    legendItem.append("text")
      .attr("x", 20)
      .attr("y", 7.5)
      .attr("dy", "0.3em")
      .text( function(d,i) { return d; });

    this.UpdatePlot();
};

LinePlot.prototype.UpdatePlot = function() {
    var plot = this;
    var line = d3.svg.line()
      .x( function(d) { return plot.xScale(d[0]);} )
      .y( function(d) { return plot.yScale(d[1]);} );
    var tooltip = d3.select("#plot-tooltip");
    // draw line path
    this.svg.selectAll("path").attr("d", function(d) { return line(d);});

    // draw data point
    this.svg.selectAll("circle")
      .attr("cx", function(d) { return plot.xScale(d.x);})
      .attr("cy", function(d) { return plot.yScale(d.y);});

    // draw error bar
    this.svg.selectAll(".line.yerror.bar")
      .filter(function(d) { return d.yerror;})
      .attr({
        x1: function(d) { return plot.xScale(d.x);},
        x2: function(d) { return plot.xScale(d.x);},
        y1: function(d) { return plot.yScale(d.y - d.yerror);},
        y2: function(d) { return plot.yScale(d.y + d.yerror);},
        stroke: function(d) { return plot.colorScale(d.series_index); }
      });
    this.svg.selectAll(".line.yerror.top")
      .filter(function(d) { return d.yerror;})
      .attr({
        x1: function(d) { return plot.xScale(d.x) - 3;},
        x2: function(d) { return plot.xScale(d.x) + 3;},
        y1: function(d) { return plot.yScale(d.y - d.yerror);},
        y2: function(d) { return plot.yScale(d.y - d.yerror);},
        stroke: function(d) { return plot.colorScale(d.series_index); }
      });
    this.svg.selectAll(".line.yerror.bottom")
      .filter(function(d) { return d.yerror;})
      .attr({
        x1: function(d) { return plot.xScale(d.x) - 3;},
        x2: function(d) { return plot.xScale(d.x) + 3;},
        y1: function(d) { return plot.yScale(d.y + d.yerror);},
        y2: function(d) { return plot.yScale(d.y + d.yerror);},
        stroke: function(d) { return plot.colorScale(d.series_index); }
      });
};

LinePlot.prototype.AddDescription = function() {
    var plot = this;

    // description for the specification of the plot
    var dl = this.description.append("dl");
    dl.append("dt").text("X-Axis");
    dl.append("dd").text(this.data.xlabel);
    dl.append("dt").text("Y-Axis");
    dl.append("dd").text(this.data.ylabel);
    if(this.data.series) {
      dl.append("dt").text("Series");
      dl.append("dd").text(this.data.series);
    }
    this.description.append("a").attr({target: "_blank", href: this.url}).text("show data in json");
    this.description.append("br");
    plt_url = this.url.replace(/\.json/, '.plt')
    this.description.append("a").attr({target: "_blank", href: plt_url}).text("gnuplot script file");
    this.description.append("br");
    this.description.append("a").text("delete plot").on("click", function() {
      plot.row.remove();
    });
    this.description.append("br");

    this.description.append("br").style("line-height", "400%");
    this.description.append("input").attr("type", "checkbox").on("change", function() {
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
    this.description.append("span").html("log scale on x axis");
    this.description.append("br");

    this.description.append("input").attr("type", "checkbox").on("change", function() {
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
    this.description.append("span").html("log scale on y axis");
};

LinePlot.prototype.Draw = function() {
  this.AddPlot();
  this.AddAxis();
  this.AddDescription();
};

function draw_line_plot(url, parameter_set_base_url, current_ps_id) {
  var plot = new LinePlot();
  var progress = show_loading_spin_arc(plot.svg, plot.width, plot.height);
  var xhr = d3.json(url)
    .on("load", function(dat) {
    progress.remove();
    plot.Init(dat, url, parameter_set_base_url, current_ps_id);
    plot.Draw(dat);
  })
  .on("error", function() {progress.remove();})
  .get();
  progress.on("mousedown", function(){
    xhr.abort();
    plot.Destructor();
  });
}

function draw_scatter_plot(url, parameter_set_base_url, current_ps_id) {
  var margin = {top: 10, right: 100, bottom: 100, left: 100};
  var width = 560;
  var height = 460;

  var row = d3.select("#plot").insert("div","div").attr("class", "row");
  var plot_region = row.append("div").attr("class", "span8");
  var description = row.append("div").attr("class", "span4");

  var svg = plot_region.insert("svg")
    .attr({
      "width": width + margin.left + margin.right,
      "height": height + margin.top + margin.bottom
    });
  var colorMapG = svg.append("g")
    .attr("transform", "translate(" + (margin.left + width) + "," + margin.top + ")");
  var svg = svg.append("g")
    .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

  var progress = show_loading_spin_arc(svg, width, height);

  var xhr = d3.json(url)
    .on("load", function(dat) {
    progress.remove();

    var scales = ["linear","log"];
    var xScale_current = 0;
    var yScale_current = 0;
    var xScale = d3.scale.linear().range([0, width]);
    var yScale = d3.scale.linear().range([height, 0]);

    var colorScale = d3.scale.linear().range(["#0041ff", "#ffffff", "#ff2800"]);
    var colorScalePoint = d3.scale.linear().range(["#0041ff", "#888888", "#ff2800"]);
    var xlabel = dat.xlabel;
    var ylabel = dat.ylabel;

    xScale.domain([
      d3.min( dat.data, function(d) { return d[0][xlabel];}),
      d3.max( dat.data, function(d) { return d[0][xlabel];})
    ]).nice();
    yScale.domain([
      d3.min( dat.data, function(d) { return d[0][ylabel];}),
      d3.max( dat.data, function(d) { return d[0][ylabel];})
    ]).nice();
    var result_min_val = d3.min( dat.data, function(d) { return d[1];});
    var result_max_val = d3.max( dat.data, function(d) { return d[1];});
    colorScale.domain([ result_min_val, (result_min_val+result_max_val)/2.0, result_max_val]).nice();
    colorScalePoint.domain( colorScale.domain() ).nice();

    function draw_color_map(g) {
      var scale = d3.scale.linear().domain([0.0, 0.5, 1.0]).range(colorScale.range());
      g.append("text")
        .attr({x: 10.0, y: 20.0, dx: "0.1em", dy: "-0.4em"})
        .style("text-anchor", "begin")
        .text("Result");
      g.selectAll("rect")
        .data([1.0, 0.8, 0.6, 0.4, 0.2, 0.0])
        .enter().append("rect")
        .attr({
          x: 10.0,
          y: function(d,i) { return i * 20.0 + 20.0; },
          width: 19,
          height: 19,
          fill: function(d) { return scale(d); }
        });
      g.append("text")
        .attr({x: 30.0, y: 40.0, dx: "0.2em", dy: "-0.3em"})
        .style("text-anchor", "begin")
        .text( colorScale.domain()[2] );
      g.append("text")
        .attr({x: 30.0, y: 140.0, dx: "0.2em", dy: "-0.3em"})
        .style("text-anchor", "begin")
        .text( colorScale.domain()[0] );
    }
    draw_color_map(colorMapG);

    var vertices = dat.data.map(function(v) {
      return [
        xScale(v[0][xlabel]) + Math.random() * 1.0 - 0.5, // noise size 1.0 is a good value
        yScale(v[0][ylabel]) + Math.random() * 1.0 - 0.5
      ];
    });
    var voronoi = d3.geom.voronoi()
      .clipExtent([[0, 0], [width, height]]);
    var voronoi_group = svg.append("g");
    var path = voronoi_group.selectAll("path")
      .data(voronoi(vertices));
    function draw_voronoi_heat_map() {
      // add noise to coordinates of vertices in order to prevent hang-up.
      // hanging-up sometimes happen when duplicated points are included.
      path.enter().append("path")
        .style("fill", function(d, i) { return colorScale(dat.data[i][1]);})
        .attr("d", function(d) { return "M" + d.join("L") + "Z"; })
        .style("fill-opacity", 0.7)
        .style("stroke", "none");
    }
    try {
      draw_voronoi_heat_map();
      // Voronoi division fails when duplicate points are included.
      // In that case, just ignore creating voronoi heatmap and continue plotting.
    } catch(e) {
      console.log(e);
    }

    var xAxis = d3.svg.axis();
    var yAxis = d3.svg.axis();
    function draw_axes(xlabel, ylabel) {
      // X-Axis
      xAxis
        .scale(xScale)
        .orient("bottom");
      svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + height + ")")
        .call(xAxis)
        .append("text")
          .style("text-anchor", "middle")
          .attr("x", width / 2.0)
          .attr("y", 50.0)
          .text(xlabel);

      // Y-Axis
      yAxis
        .scale(yScale)
        .orient("left");
      svg.append("g")
        .attr("class", "y axis")
        .call(yAxis)
        .append("text")
          .attr("transform", "rotate(-90)")
          .attr("x", -height/2)
          .attr("y", -50.0)
          .style("text-anchor", "middle")
          .text(ylabel);
    }
    draw_axes(dat.xlabel, dat.ylabel);

    var mapped = dat.data.map(function(v) {
      return {
        x: v[0][xlabel], y: v[0][ylabel],
        average: v[1], error: v[2], psid: v[3]
      };
    });
    var tooltip = d3.select("#plot-tooltip");
    var point = svg.selectAll("circle")
      .data(mapped).enter();
    function draw_points() {
      point.append("circle")
        .attr("cx", function(d) { return xScale(d.x);})
        .attr("cy", function(d) { return yScale(d.y);})
        .style("fill", function(d) { return colorScalePoint(d.average);})
        .attr("r", function(d) { return (d.psid == current_ps_id) ? 5 : 3;})
        .on("mouseover", function(d) {
          tooltip.transition()
            .duration(200)
            .style("opacity", .8);
          tooltip.html(
            dat.xlabel + " : " + d.x + "<br/>" +
            dat.ylabel + " : " + d.y + "<br/>" +
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
          window.open(parameter_set_base_url + d.psid, '_blank');
        });
    }
    draw_points();

    function update_plot() {
      svg.selectAll("circle").remove();
      draw_points();
      voronoi_group.selectAll("path").remove();
      //svg.selectAll("path").remove();
      vertices = dat.data.map(function(v) {
        return [
          xScale(v[0][xlabel]) + Math.random() * 1.0 - 0.5, // noise size 1.0 is a good value
          yScale(v[0][ylabel]) + Math.random() * 1.0 - 0.5
        ];
      });
      path = voronoi_group.selectAll("path")
            .data(voronoi(vertices));
      try {
        draw_voronoi_heat_map();
        // Voronoi division fails when duplicate points are included.
        // In that case, just ignore creating voronoi heatmap and continue plotting.
      } catch(e) {
        console.log(e);
      }
    }

    function add_description() {
      // description for the specification of the plot
      var dl = description.append("dl");
      dl.append("dt").text("X-Axis");
      dl.append("dd").text(dat.xlabel);
      dl.append("dt").text("Y-Axis");
      dl.append("dd").text(dat.ylabel);
      dl.append("dt").text("Result");
      dl.append("dd").text(dat.result);
      description.append("a").attr({target: "_blank", href: url}).text("show data in json");
      description.append("br");
      description.append("a").text("delete plot").on("click", function() {
        row.remove();
      });
      description.append("br");
      description.append("br");
      description.append("br");
      description.append("br");
      description.append("input").attr("type", "checkbox").on("change", function() {
          xScale_current = 1 - xScale_current;
          switch(scales[xScale_current]) {
          case "linear":
          xScale = d3.scale.linear().range([0, width]);
          xScale.domain([
            d3.min( dat.data, function(d) { return d[0][xlabel];}),
            d3.max( dat.data, function(d) { return d[0][xlabel];})
            ]).nice();
          break;
          case "log":
          xScale = d3.scale.log().clamp(true).range([0, width]);
          var min = d3.min( dat.data, function(d) { return d[0][xlabel];});
          xScale.domain([
            (min<0.1 ? 0.1 : min),
            d3.max( dat.data, function(d) { return d[0][xlabel];})
            ]).nice();
          break;
          }

          update_plot();
          xAxis.scale(xScale);
          svg.select(".x.axis").call(xAxis);
      });
      description.append("span").html("log scale on x axis");
      description.append("br");
      description.append("input").attr("type", "checkbox").on("change", function() {
          yScale_current = 1 - yScale_current;
          switch(scales[yScale_current]) {
          case "linear":
          yScale = d3.scale.linear().range([height, 0]);
          yScale.domain([
            d3.min( dat.data, function(d) { return d[0][ylabel];}),
            d3.max( dat.data, function(d) { return d[0][ylabel];})
            ]).nice();
          break;
          case "log":
          yScale = d3.scale.log().clamp(true).range([height, 0]);
          var min = d3.min( dat.data, function(d) { return d[0][ylabel];});
          yScale.domain([
            (min<0.1 ? 0.1 : min),
            d3.max( dat.data, function(d) { return d[0][ylabel];})
            ]).nice();
          break;
          }

          update_plot();
          yAxis.scale(yScale);
          svg.select(".y.axis").call(yAxis);
      });
      description.append("span").html("log scale on y axis");
    }
    add_description();
  })
  .on("error", function() {progress.remove();})
  .get();
  progress.on("mousedown", function(){
    xhr.abort();
    row.remove();
  });
}

function draw_figure_viewer(url, parameter_set_base_url, current_ps_id) {
  var margin = {top: 10+92, right: 100+112, bottom: 100, left: 100};
  var width = 560;
  var height = 460;
  var image_scale = "middle"; // [{"point"=>3 or 5 px},{"middle"=>width/10 px},{"large"=>width/5 px}]

  var row = d3.select("#plot").insert("div","div").attr("class", "row");
  var plot_region = row.append("div").attr("class", "span8");
  var description = row.append("div").attr("class", "span4");

  var svg = plot_region.insert("svg")
    .attr({
      "width": width + margin.left + margin.right,
      "height": height + margin.top + margin.bottom
    });
  var svg = svg.append("g")
    .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

  var progress = show_loading_spin_arc(svg, width, height);

  var xhr = d3.json(url)
    .on("load", function(dat) {
    progress.remove();

    var scales = ["linear","log"];
    var xScale_current = 0;
    var yScale_current = 0;
    var xScale = d3.scale.linear().range([0, width]);
    var yScale = d3.scale.linear().range([height, 0]);

    xScale.domain([
      d3.min( dat.data, function(d) { return d[0];}),
      d3.max( dat.data, function(d) { return d[0];})
    ]).nice();
    yScale.domain([
      d3.min( dat.data, function(d) { return d[1];}),
      d3.max( dat.data, function(d) { return d[1];})
    ]).nice();

    var xAxis;
    var yAxis;
    function draw_axes(xlabel, ylabel) {
      // X-Axis
      xAxis = d3.svg.axis()
        .scale(xScale)
        .orient("bottom");
      svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + height + ")")
        .call(xAxis)
        .append("text")
          .style("text-anchor", "middle")
          .attr("x", width / 2.0)
          .attr("y", 50.0)
          .text(xlabel);

      // Y-Axis
      yAxis = d3.svg.axis()
        .scale(yScale)
        .orient("left");
      svg.append("g")
        .attr("class", "y axis")
        .call(yAxis)
        .append("text")
          .attr("transform", "rotate(-90)")
          .attr("x", -height/2)
          .attr("y", -50.0)
          .style("text-anchor", "middle")
          .text(ylabel);
    }
    draw_axes(dat.xlabel, dat.ylabel);

    var mapped = dat.data.map(function(v) {
      return { x: v[0], y: v[1], path:v[2], psid: v[3] };
    });

    function append_figure(elements, divide) {
      var image = elements.append("svg:image")
        .attr("x", function(d) { return xScale(d.x);})
        .attr("y", function(d) { return yScale(d.y) - height/divide;})
        .attr("xlink:href", function(d) { return d.path; })
        .attr("width", width/divide)
        .attr("height", height/divide);
      assign_mouse_event(image);
    }

    function append_circle(elements) {
      var circle = elements.append("circle")
        .attr("cx", function(d) { return xScale(d.x);})
        .attr("cy", function(d) { return yScale(d.y);})
        .style("fill", function() { return "black";})
        .attr("r", function(d) { return (d.psid == current_ps_id) ? 5 : 3;});
      assign_mouse_event(circle);
    }

    function assign_mouse_event(elements) {
      var tooltip = d3.select("#plot-tooltip");
      elements.on("mouseover", function(d) {
          tooltip.transition()
            .duration(200)
            .style("opacity", 0.8);
          tooltip.html(function() {
            var str = dat.xlabel + " : " + d.x + "<br/>" +
            dat.ylabel + " : " + d.y + "<br/>" +
            "ID: " + d.psid + "<br />";
            if(d.path) {
              str += '<img src="' + d.path + '" width="300px" />';
            } else {
              str += "<br />"+"<br />"+"NO IMAGE"+"<br />"+"<br />";
            }
            return str;
          });
        })
        .on("mousemove", function() {
          tooltip
            .style("top", (d3.event.pageY-300) + "px")
            .style("left", (d3.event.pageX-150) + "px");
        })
        .on("mouseout", function() {
          tooltip.transition()
            .duration(300)
            .style("opacity", 0);
        })
        .on("dblclick", function(d) {
          window.open(parameter_set_base_url + d.psid, '_blank');
        });
    }

    var imgs = svg.selectAll("image").data(mapped).enter();
    function draw_figures() {
      append_figure(imgs, 10);
    }
    draw_figures();

    function update_plot() {
      switch(image_scale) {
        case "point":
          var points = svg.selectAll("circle");
          points.remove();
          points = svg.selectAll("circle").data(mapped).enter();
          append_circle(points);
          break;
        case "middle":
          svg.selectAll("image").remove();
          append_figure(imgs, 10);
          break;
        case "large":
          svg.selectAll("image").remove();
          append_figure(imgs, 5);
          break;
      }
    }

    function add_description() {
      // description for the specification of the plot
      var dl = description.append("dl");
      dl.append("dt").text("X-Axis");
      dl.append("dd").text(dat.xlabel);
      dl.append("dt").text("Y-Axis");
      dl.append("dd").text(dat.ylabel);
      dl.append("dt").text("Result");
      dl.append("dd").text(dat.result);
      description.append("a").attr({target: "_blank", href: url}).text("show data in json");
      description.append("br");
      description.append("a").text("show small image").on("click", function() {
        var imgs = svg.selectAll("image");
        if(image_scale == "middle") {
          image_scale = "point";
          imgs.remove();
          var points = svg.selectAll("circle").data(mapped).enter();
          append_circle(points);
        }
        else if (image_scale == "large") {
          image_scale = "middle";
          imgs.remove();
          imgs = svg.selectAll("image").data(mapped).enter();
          append_figure(imgs, 10);
        }
      });
      description.append("br");
      description.append("a").text("show large image").on("click", function() {
        var imgs = svg.selectAll("image");
        var points = svg.selectAll("circle");
        if(image_scale == "point") {
          image_scale = "middle";
          points.remove();
          imgs = svg.selectAll("image").data(mapped).enter();
          append_figure(imgs, 10);
        }
        else if(image_scale == "middle") {
          image_scale = "large";
          imgs.remove();
          imgs = svg.selectAll("image").data(mapped).enter();
          append_figure(imgs, 5);
        }
      });

      description.append("br");
      description.append("a").text("delete plot").on("click", function() {
        row.remove();
      });
      description.append("br");
      description.append("br");
      description.append("br");
      description.append("br");
      description.append("input").attr("type", "checkbox").on("change", function() {
        xScale_current = 1 - xScale_current;
        switch(scales[xScale_current]) {
          case "linear":
          xScale = d3.scale.linear().range([0, width]);
          xScale.domain([
            d3.min( dat.data, function(d) { return d[0];}),
            d3.max( dat.data, function(d) { return d[0];})
          ]).nice();
          break;

          case "log":
          xScale = d3.scale.log().clamp(true).range([0, width]);
          var min = d3.min( dat.data, function(d) { return d[0];});
          xScale.domain([
            (min<0.1 ? 0.1 : min),
            d3.max( dat.data, function(d) { return d[0];})
            ]).nice();
          break;
        }

        update_plot();
        xAxis.scale(xScale);
        svg.select(".x.axis").call(xAxis);
      });
      description.append("span").html("log scale on x axis");
      description.append("br");
      description.append("input").attr("type", "checkbox").on("change", function() {
          yScale_current = 1 - yScale_current;
          switch(scales[yScale_current]) {
          case "linear":
          yScale = d3.scale.linear().range([height, 0]);
          yScale.domain([
            d3.min( dat.data, function(d) { return d[1];}),
            d3.max( dat.data, function(d) { return d[1];})
            ]).nice();
          break;
          case "log":
          yScale = d3.scale.log().clamp(true).range([height, 0]);
          var min = d3.min( dat.data, function(d) { return d[1];});
          yScale.domain([
            (min<0.1 ? 0.1 : min),
            d3.max( dat.data, function(d) { return d[1];})
            ]).nice();
          break;
          }

          update_plot();
          yAxis.scale(yScale);
          svg.select(".y.axis").call(yAxis);
      });
      description.append("span").html("log scale on y axis");
    }
    add_description();
  })
  .on("error", function() {progress.remove();})
  .get();
  progress.on("mousedown", function(){
    xhr.abort();
    row.remove();
  });
}
