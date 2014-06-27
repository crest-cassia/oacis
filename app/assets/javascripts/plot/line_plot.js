function LinePlot() {
  Plot.call(this);// call constructor of Plot
}

LinePlot.prototype = Object.create(Plot.prototype);// LinePlot is sub class of Plot
LinePlot.prototype.constructor = LinePlot;// override constructor
LinePlot.prototype.IsLog = [false,false];

LinePlot.prototype.SetXScale = function(xscale) {
  var scale = null, min, max;
  switch(xscale) {
  case "linear":
    scale = d3.scale.linear().range([0, this.width]);
    min = d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[0];});});
    max = d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[0];});});
    scale.domain([
      min,
      max
    ]).nice();
    break;
  case "log":
    var data_in_logscale = this.data.data.map(function(element) {
      return element.filter(function(element){
        return element[0] > 0.0;
      });
    });
    scale = d3.scale.log().clamp(true).range([0, this.width]);
    min = d3.min( data_in_logscale, function(r) { return d3.min(r, function(v) { return v[0];});});
    max = d3.max( data_in_logscale, function(r) { return d3.max(r, function(v) { return v[0];});});
    scale.domain([
      (!min || min<0.0) ? 0.1 : min,
      (!max || max<0.0) ? 1.0 : max
    ]).nice();
    break;
  }
  this.xScale = scale;
  this.xAxis.scale(this.xScale);
};

LinePlot.prototype.SetYScale = function(yscale) {
  var scale = null, min, max;
  switch(yscale) {
  case "linear":
    scale = d3.scale.linear().range([this.height, 0]);
    min = d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[1] - v[2];});});
    max = d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[1] + v[2];});});
    scale.domain([
      min,
      max
    ]).nice();
    break;
  case "log":
    var data_in_logscale = this.data.data.map(function(element) {
      return element.filter(function(element){
        return element[0] > 0.0;
      });
    });
    scale = d3.scale.log().clamp(true).range([this.height, 0]);
    min = d3.min( this.data.data, function(r) { return d3.min(r, function(v) { return v[1] - v[2];});});
    max = d3.max( this.data.data, function(r) { return d3.max(r, function(v) { return v[1] + v[2];});});
    scale.domain([
      (!min || min<0.0) ? 0.1 : min,
      (!max || max<0.0) ? 1.0 : max
    ]).nice();
    break;
  }
  this.yScale = scale;
  this.yAxis.scale(this.yScale);
};

LinePlot.prototype.SetXDomain = function(xmin, xmax) {
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

LinePlot.prototype.SetYDomain = function(ymin, ymax) {
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

LinePlot.prototype.AddPlot = function() {
  var plot = this;
  var colorScale = d3.scale.category10();

  function add_series_group() {
    var series = plot.main_group
      .selectAll("g")
      .data(plot.data.data)
      .enter().append("g")
        .attr("class", function(d, i) { return "series group-"+i;});

    // add line
    series.append("path")
      .attr("clip-path", "url(#clip)")
      .style({
        "stroke": function(d, i) { return colorScale(i);},
        "fill": "none",
        "stroke-width": "1.5px"
      });

    // add circle
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
      .attr("clip-path", "url(#clip)")
      .style("fill", function(d) { return colorScale(d.series_index);})
      .attr("r", function(d) { return (d.psid == plot.current_ps_id) ? 5 : 3;})
      .on("mouseover", function(d) {
        tooltip.transition()
          .duration(200)
          .style("opacity", 0.8);
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

    // add error bar
    point.insert("line", "circle")
      .attr("clip-path", "url(#clip)")
      .attr("class", "line yerror bar");
    point.insert("line", "circle")
      .attr("clip-path", "url(#clip)")
      .attr("class", "line yerror top");
    point.insert("line", "circle")
      .attr("clip-path", "url(#clip)")
      .attr("class", "line yerror bottom");
  }
  add_series_group();

  function add_legend_group() {
    var legend_region = plot.main_group.append("g")
      .attr("id", "legend-group")
      .attr("transform", "translate(" + plot.width + "," + 0 + ")");
    var legend = legend_region.append("g")
      .attr("id", "legend")
      .attr("transform", "translate(" + 0 + "," + 20 + ")");

    // add legend
    var legendItem = legend.selectAll("g")
      .data(plot.data.series_values)
      .enter().append("g")
      .attr("class", "legend-item")
      .attr("transform", function(d,i) {
        return "translate(10," + (i*20) + ")";
      });
    legendItem.append("rect")
      .attr("width", 15)
      .attr("height", 15)
      .style("fill", function(d,i) { return colorScale(i);});
    legendItem.append("text")
      .attr("x", 20)
      .attr("y", 7.5)
      .attr("dy", "0.3em")
      .text( function(d) { return d; });

    // add legend title
    var legend_title = legend_region.append("g")
      .attr("id", "legend-title");
    legend_title.append("text")
      .attr({
        x: 0,
        y: 0,
        dx: ".8em",
        dy: ".8em"
      })
      .text(plot.data.series);
  }
  add_legend_group();

  this.UpdatePlot();
};

LinePlot.prototype.UpdatePlot = function() {
  var plot = this;
  var colorScale = d3.scale.category10();
  var line = d3.svg.line()
    .x( function(d) { return plot.xScale(d[0]);} )
    .y( function(d) { return plot.yScale(d[1]);} );

  function update_series() {
    var series = plot.main_group.selectAll("g.series");
    // draw line path
    series.selectAll("path").attr("d", function(d) { return line(d);});

    // draw data point
    series.selectAll("circle")
      .attr("cx", function(d) { return plot.xScale(d.x);})
      .attr("cy", function(d) { return plot.yScale(d.y);});

    // draw error bar
    series.selectAll(".line.yerror.bar")
      .filter(function(d) { return d.yerror;})
      .attr({
        x1: function(d) { return plot.xScale(d.x);},
        x2: function(d) { return plot.xScale(d.x);},
        y1: function(d) { return plot.yScale(d.y - d.yerror);},
        y2: function(d) { return plot.yScale(d.y + d.yerror);},
        stroke: function(d) { return colorScale(d.series_index); }
      });
    series.selectAll(".line.yerror.top")
      .filter(function(d) { return d.yerror;})
      .attr({
        x1: function(d) { return plot.xScale(d.x) - 3;},
        x2: function(d) { return plot.xScale(d.x) + 3;},
        y1: function(d) { return plot.yScale(d.y - d.yerror);},
        y2: function(d) { return plot.yScale(d.y - d.yerror);},
        stroke: function(d) { return colorScale(d.series_index); }
      });
    series.selectAll(".line.yerror.bottom")
      .filter(function(d) { return d.yerror;})
      .attr({
        x1: function(d) { return plot.xScale(d.x) - 3;},
        x2: function(d) { return plot.xScale(d.x) + 3;},
        y1: function(d) { return plot.yScale(d.y + d.yerror);},
        y2: function(d) { return plot.yScale(d.y + d.yerror);},
        stroke: function(d) { return colorScale(d.series_index); }
      });
  }
  update_series();

  this.UpdateAxis();
};

LinePlot.prototype.AddDescription = function() {
  var plot = this;

  // description for the specification of the plot
  function add_label_table() {
    var dl = plot.description.append("dl");
    dl.append("dt").text("X-Axis");
    dl.append("dd").text(plot.data.xlabel);
    dl.append("dt").text("Y-Axis");
    dl.append("dd").text(plot.data.ylabel);
    if(plot.data.series) {
      dl.append("dt").text("Series");
      dl.append("dd").text(plot.data.series);
    }
  }
  add_label_table();

  function add_tools() {
    plot.description.append("a").attr({target: "_blank", href: plot.url}).text("show data in json");
    plot.description.append("br");
    var plt_url = plot.url.replace(/\.json/, '.plt');
    plot.description.append("a").attr({target: "_blank", href: plt_url}).text("gnuplot script file");
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
    var a_link = downloadAsFile("line_plot.svg", $(plot.svg.node()).parent().html());
    $(a_link).text("download svg");
    plot.description.node().appendChild(a_link);
    plot.description.append("br");
    plot.description.append("a").text("delete plot").style('cursor','pointer').on("click", function() {
      plot.Destructor();
    });
    plot.description.append("br");

    plot.description.append("br").style("line-height", "400%");
    plot.description.append("input").attr("type", "checkbox").on("change", function() {
      var new_scale;
      if(this.checked) {
        new_scale = "log";
        plot.IsLog[0]=true;
      } else {
        new_scale = "linear";
        plot.IsLog[0]=false;
      }
      var x_min = d3.min( plot.data.data, function(r) { return d3.min(r, function(v) { return v[0];});});
      var x_max = d3.max( plot.data.data, function(r) { return d3.max(r, function(v) { return v[0];});});
      var y_min = d3.min( plot.data.data, function(r) { return d3.min(r, function(v) { return v[1] - v[2];});});
      var y_max = d3.max( plot.data.data, function(r) { return d3.max(r, function(v) { return v[1] + v[2];});});
      var axis_domain = [[x_min,y_min],[x_max, y_max]];
      plot.SetXDomain(axis_domain[0][0], axis_domain[1][0]);
      plot.SetYDomain(axis_domain[0][1], axis_domain[1][1]);
      plot.SetXScale(new_scale);
      plot.UpdatePlot();
      while (control_plot[0][0].firstChild) {
        control_plot[0][0].removeChild(control_plot[0][0].firstChild);
      }
      add_brush();
    });
    plot.description.append("span").html("log scale on x axis");
    plot.description.append("br");

    plot.description.append("input").attr("type", "checkbox").on("change", function() {
      var new_scale;
      if(this.checked) {
        new_scale = "log";
        plot.IsLog[1]=true;
      } else {
        new_scale = "linear";
        plot.IsLog[1]=false;
      }
      var x_min = d3.min( plot.data.data, function(r) { return d3.min(r, function(v) { return v[0];});});
      var x_max = d3.max( plot.data.data, function(r) { return d3.max(r, function(v) { return v[0];});});
      var y_min = d3.min( plot.data.data, function(r) { return d3.min(r, function(v) { return v[1] - v[2];});});
      var y_max = d3.max( plot.data.data, function(r) { return d3.max(r, function(v) { return v[1] + v[2];});});
      var axis_domain = [[x_min,y_min],[x_max, y_max]];
      plot.SetXDomain(axis_domain[0][0], axis_domain[1][0]);
      plot.SetYDomain(axis_domain[0][1], axis_domain[1][1]);
      plot.SetYScale(new_scale);
      plot.UpdatePlot();
      while (control_plot[0][0].firstChild) {
        control_plot[0][0].removeChild(control_plot[0][0].firstChild);
      }
      add_brush();
    });
    plot.description.append("span").html("log scale on y axis");

    plot.description.append("br");
    var control_plot = plot.description.append("div");
    function add_brush() {
      var clone = plot.svg.node().cloneNode(true);
      d3.select(clone)
        .attr("width","240")
        .attr("height","215")
        .attr("viewBox","0 0 780 580");

      control_plot[0][0].appendChild(clone);
      var x = d3.scale.linear().range([0, plot.width]);
      var x_min = d3.min( plot.data.data, function(r) { return d3.min(r, function(v) { return v[0];});});
      var x_max = d3.max( plot.data.data, function(r) { return d3.max(r, function(v) { return v[0];});});
      x.domain([x_min]).nice();

      var y = d3.scale.linear().range([plot.height, 0]);
      var y_min = d3.min( plot.data.data, function(r) { return d3.min(r, function(v) { return v[1] - v[2];});});
      var y_max = d3.max( plot.data.data, function(r) { return d3.max(r, function(v) { return v[1] + v[2];});});
      y.domain([y_min, y_max]).nice();

      var brush = d3.svg.brush()
        .x(x)
        .y(y)
        .on("brush", brushed);

      var cloned_main_group = d3.select(clone.children[0])
        .attr("transform", "translate(20,0)");
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
        plot.main_group.select(".x.axis").call(plot.xAxis);
        plot.main_group.select(".y.axis").call(plot.yAxis);
      }
    }
    add_brush();
  }
  add_tools();

};

LinePlot.prototype.Draw = function() {
  this.AddPlot();
  this.AddAxis();
  this.AddDescription();
};

function draw_line_plot(url, parameter_set_base_url, current_ps_id) {
  var plot = new LinePlot();
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

