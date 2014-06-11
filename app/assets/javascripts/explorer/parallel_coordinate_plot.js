function ParallelCoordinatePlot(pe_plot) {
  this.row = d3.select("#pc-plot").insert("div","div").attr("class", "row");
  this.pe_plot = pe_plot;
}

ParallelCoordinatePlot.prototype.margin = {top: 50, right: 100, bottom: 50, left: 100};
ParallelCoordinatePlot.prototype.width = 1000;
ParallelCoordinatePlot.prototype.height = 200;
ParallelCoordinatePlot.prototype.data = null;
ParallelCoordinatePlot.prototype.brushes = {};
ParallelCoordinatePlot.prototype.xScale = null;
ParallelCoordinatePlot.prototype.yScales = {};
ParallelCoordinatePlot.prototype.current_ps_id = null;
ParallelCoordinatePlot.prototype.modified_domains = {};

ParallelCoordinatePlot.prototype.Init = function(data, current_ps_id) {
  var plot = this;
  this.data = data;
  this.current_ps_id = current_ps_id;

  var svg = this.row.insert("svg")
    .attr({
      "width": this.width + this.margin.left + this.margin.right,
      "height": this.height + this.margin.top + this.margin.bottom,
      "id": "pc-plot-svg"
    })
    .append("g")
    .attr({
      "transform": "translate(" + this.margin.left + "," + this.margin.top + ")",
      "id": "pc-plot-group"
    });

  var dimensions = Object.keys(data.data[0][0]);
  function set_scales_and_dimensions() {
    dimensions.forEach(function(key) {
      var domain = plot.pe_plot.GetCurrentRangeFor(key);
      var scale = d3.scale.linear().domain(domain).range([plot.height, 0]).nice();
      plot.yScales[key] = scale;
      plot.modified_domains[key] = domain;
    });
  }
  set_scales_and_dimensions();

  this.xScale = d3.scale.ordinal().rangePoints([0,this.width], 1).domain( dimensions );

  function draw_axis() {
    var xScale = plot.xScale;
    var dimension_g = svg.selectAll(".dimension")
      .data(dimensions)
      .enter().append("svg:g")
      .attr("class", "dimension")
      .attr("transform", function(key) { return "translate(" + xScale(key) + ")"; });

    var axis = d3.svg.axis().orient("left");
    dimension_g.append("svg:g")
      .attr("class", "pcp-axis")
      .each(function(key) {
        d3.select(this).call( axis.scale(plot.yScales[key]) );
      })
      .append("svg:text")
      .attr("text-anchor", "middle")
      .attr("y", -9)
      .text(String); // set text to the data values
  }
  draw_axis();

  function set_brsuh() {
    svg.selectAll(".dimension").each(function(key) {
      plot.brushes[key] = d3.svg.brush().y( plot.yScales[key] ).on("brushend", function() { plot.BrushEvent(key); });
      d3.select(this).append("svg:g")
        .attr("class", "brush")
        .call(plot.brushes[key])
        .selectAll("rect")
        .attr("x", -8)
        .style({stroke: "orange", "fill-opacity": 0.125, "shape-rendering": "crispEdges"})
        .attr("width", 16);
    });
  }
  set_brsuh();

  function set_logscale_checkbox() {
    svg.selectAll(".dimension").each(function(key) {
      d3.select(this).append("svg:g").append("svg:input")
        .attr("type", "checkbox")
        .attr("class", "checkbox-log-scale")
        .attr("y", 10+plot.yScales[key])
        .on("change", function() { plot.LogScaleEvent(key, this.checked); });
    });
  }
  set_logscale_checkbox();
};

ParallelCoordinatePlot.prototype.BrushEvent = function(key) {
  var plot = this;
  var domain = plot.brushes[key].empty() ? plot.yScales[key].domain() : plot.brushes[key].extent();
  plot.pe_plot.SetCurrentRangeFor(key, plot.brushes[key].empty() ? null : domain );
  if(!plot.brushes[key].empty()) {
    plot.modified_domains[key] = domain;
  } else {
    delete plot.modified_domains[key];
  }
  plot.Update();
};

ParallelCoordinatePlot.prototype.Destructor = function() {
  this.row.remove();
};

ParallelCoordinatePlot.prototype.Update = function() {
  var plot = this;
  var svg = d3.select('#pc-plot-group');
  var dimensions = svg.selectAll(".dimension").data();
  var xScale = this.xScale;
  var yScales = this.yScales;
  var colorScale = d3.scale.linear().range(["#0041ff", "#888888", "#ff2800"]);
  var min = d3.min( this.data.data, function(v) { return v[1];});
  var max = d3.max( this.data.data, function(v) { return v[1];});
  var middle = (min + max) / 2.0;
  var domain = [ min, middle, max ];
  colorScale.domain(domain).nice();

  function redraw_path() {
    d3.selectAll('g.pcp-path').remove();
    var pcp_path = svg.append("svg:g")
      .attr("class", "pcp-path")
      .selectAll("path")
      .data(plot.data.data);
    pcp_path.enter().append("svg:path");
    pcp_path
      .filter(function(d) {
        var is_in_range=true, key;
        Object.keys(d[0]).forEach( function(key) {
          var domain = plot.pe_plot.GetCurrentRangeFor(key);
          is_in_range &= (domain[0] <= d[0][key] && domain[1] >= d[0][key]);
        });
        return is_in_range;
      })
      .style({ "fill": "none", "stroke-opacity": 0.7})
      .attr("d", function(d) {
        var points = Object.keys(d[0]).map( function(p) {
          return [ xScale(p), yScales[p]( d[0][p] ) ];
        });
        return d3.svg.line()(points);
      })
      .attr("stroke-width", function(d) {
        return d[3] == plot.current_ps_id ? 3 : 1;
      })
      .attr("stroke", function(d) {
        if( colorScale ) { return colorScale(d[1]); }
        else { return "steelblue"; }
      });
  }
  redraw_path();
};

