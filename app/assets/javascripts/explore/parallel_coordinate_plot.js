function ParallelCoordinatePlot(ps_plot) {
  this.row = d3.select("#pc-plot").insert("div","div").attr("class", "row");
  this.ps_plot = ps_plot;
};

ParallelCoordinatePlot.prototype.data = null;
ParallelCoordinatePlot.prototype.UpdateParameterExplore = null;

ParallelCoordinatePlot.prototype.Init = function(data) {
  var plot = this;
  this.data = data;

  var margin = {top: 50, right: 100, bottom: 50, left: 100};
  var width = 1000;
  var height = 200;

  var svg = this.row.insert("svg")
    .attr({
      "width": width + margin.left + margin.right,
      "height": height + margin.top + margin.bottom,
      "id": "pc-plot-svg"
    })
    .append("g")
    .attr({
      "transform": "translate(" + margin.left + "," + margin.top + ")",
      "id": "pc-plot-group"
    });

  var dimensions = [];
  var yScales = {};
  function set_scales_and_dimensions() {
    $('select#x_axis_key option').each(function() {
      var key = $(this).text();
      var domain = get_current_range_for(key);
      var scale = d3.scale.linear().domain(domain).range([height, 0]).nice();
      yScales[key] = scale;
      dimensions.push(key);
    });
  }
  set_scales_and_dimensions();

  window.pcp_x_scale = d3.scale.ordinal().rangePoints([0,width], 1).domain( dimensions );
  window.pcp_y_scales = yScales;

  function draw_axis() {
    var xScale = window.pcp_x_scale;
    var dimension_g = svg.selectAll(".dimension")
      .data(dimensions)
      .enter().append("svg:g")
      .attr("class", "dimension")
      .attr("transform", function(d) { return "translate(" + xScale(d) + ")"; });

    var axis = d3.svg.axis().orient("left");
    dimension_g.append("svg:g")
      .attr("class", "pcp-axis")
      .each(function(d) {
        d3.select(this).call( axis.scale(yScales[d]) );
      })
      .append("svg:text")
      .attr("text-anchor", "middle")
      .attr("y", -9)
      .text(String); // set text to the data values
  }
  draw_axis();

  function set_brsuh() {
    svg.selectAll(".dimension").each(function(d) {
      var brush = d3.svg.brush().y( window.pcp_y_scales[d] ).on("brushend", on_brush_end);
      function on_brush_end() {
        var domain = brush.empty() ? null : brush.extent();
        set_current_range_for( d, domain );
        plot.ps_plot.Update();
      }
      // to clear current range, set range to null
      function set_current_range_for(parameter_key, range) {
        $('td#ps_v_' + parameter_key).data('current-range', range);
      }

      d3.select(this).append("svg:g")
        .attr("class", "brush")
        .call(brush)
        .selectAll("rect")
        .attr("x", -8)
        .style({stroke: "orange", "fill-opacity": 0.125, "shape-rendering": "crispEdges"})
        .attr("width", 16);
    });
  }
  set_brsuh();
};

ParallelCoordinatePlot.prototype.Destructor = function() {
  this.row.remove();
};

ParallelCoordinatePlot.prototype.Update = function() {
  var plot = this;
  var svg = d3.select('#pc-plot-group');
  var dimensions = svg.selectAll(".dimension").data();
  var xScale = window.pcp_x_scale;
  var yScales = window.pcp_y_scales;
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
      .style({ "fill": "none", "stroke-opacity": 0.7})
      .attr("d", function(d) {
        var points = dimensions.map( function(p) {
          return [ xScale(p), yScales[p]( d[0][p] ) ];
        });
        return d3.svg.line()(points);
      })
      .attr("stroke-width", function(d) {
        return d[3] == current_ps_id ? 3 : 1;
      })
      .attr("stroke", function(d) {
        if( colorScale ) { return colorScale(d[1]); }
        else { return "steelblue"; }
      });
  }
  redraw_path();
};

