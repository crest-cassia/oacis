function LinePlot() {
  Plot.call(this);// call constructor of Plot
}

LinePlot.prototype = Object.create(Plot.prototype);// LinePlot is sub class of Plot
LinePlot.prototype.constructor = LinePlot;// override constructor

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
      var data_in_logscale = this.data.data.map(function(element, index, array) {
        return element.filter(function(element, index, array){
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
      var data_in_logscale = this.data.data.map(function(element, index, array) {
        return element.filter(function(element, index, array){
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
};

LinePlot.prototype.AddPlot = function() {
  var plot = this;
  var colorScale = d3.scale.category10();

  function add_series_group() {
    var series = plot.svg
      .selectAll("g")
      .data(plot.data.data)
      .enter().append("g")
        .attr("class", function(d, i) { return "series group-"+i;});

    // add line
    series.append("path")
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
    var legend_region = plot.svg.append("g")
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
      .text( function(d,i) { return d; });

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
  var tooltip = d3.select("#plot-tooltip");

  function update_series() {
    var series = plot.svg.selectAll("g.series");
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
    plt_url = plot.url.replace(/\.json/, '.plt');
    plot.description.append("a").attr({target: "_blank", href: plt_url}).text("gnuplot script file");
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
      plot.Draw();
    })
  .on("error", function() {progress.remove();})
  .get();
  progress.on("mousedown", function(){
    xhr.abort();
    plot.Destructor();
  });
}

