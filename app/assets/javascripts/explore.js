function set_current_ps(ps_id) {
  $('#current_ps_id').text(ps_id);

  var point = d3.selectAll("circle")
    .attr("r", function(d) { return (d.psid == ps_id) ? 5 : 3;});

  var url = $('#plot').data('ps-url').replace('PSID', ps_id);
  d3.json(url, function(error, json) {
    var param_values = json.v;
    for(key in param_values) {
      $('#ps_v_'+key).text(param_values[key]);
    }
  });
}

function move_current_ps(neighbor_ps_url) {
  var current_ps_id = $('#current_ps_id').text();
  var url = neighbor_ps_url.replace('PSID', current_ps_id);

  d3.json(url, function(error, json) {
    // update table
    var ps_id = json._id;
    $('#current_ps_id').text(ps_id);
    var param_values = json.v;
    for(key in param_values) {
      $('#ps_v_'+key).text(param_values[key]);
    }

    // update scatter plot
    var url = build_scatter_plot_url();
    update_explorer(url, ps_id);
  });
}

function build_scatter_plot_url(ps_id) {
  ps_id = ps_id || $('td#current_ps_id').text();
  var x = $('#scatter-plot-form #x_axis_key').val();
  var y = $('#scatter-plot-form #y_axis_key').val();
  var result = $('#scatter-plot-form #result').val();
  var irrelevants = $('#irrelevant-params').children("input:checkbox:checked").map(function() {
    return this.id;
    }).get().join(',');
  var url = $('#plot').data('scatter-plot-url').replace('PSID', ps_id);
  var url_with_param = url +
    "?x_axis_key=" + encodeURIComponent(x) +
    "&y_axis_key=" + encodeURIComponent(y) +
    "&result=" + encodeURIComponent(result) +
    "&irrelevants=" + encodeURIComponent(irrelevants);
  return url_with_param;
}

function draw_explorer(url, current_ps_id) {
  var margin = {top: 10, right: 100, bottom: 100, left: 100};
  var width = 560;
  var height = 460;

  var plot_region = d3.select("#plot");

  var svg = plot_region.insert("svg")
    .attr({
      "width": width + margin.left + margin.right,
      "height": height + margin.top + margin.bottom,
      "id": "plot-svg"
    });
  var colorMapG = svg.append("g")
    .attr({
      "transform": "translate(" + (margin.left + width) + "," + margin.top + ")",
      "id": "color-map-group"
    });
  var svg = svg.append("g")
    .attr({
      "transform": "translate(" + margin.left + "," + margin.top + ")",
      "id": "plot-group"
    });

  update_explorer(url, current_ps_id);
}

function update_explorer(url, current_ps_id) {
  var width = 560;
  var height = 460;
  var colorMapG = d3.select("g#color-map-group");
  var svg = d3.select("g#plot-group");

  // var progress = show_loading_spin_arc(svg, width, height);

  var xhr = d3.json(url)
    .on("load", function(dat) {
    // progress.remove();

    var xScale = d3.scale.linear().range([0, width]);
    var xDomain = $('select#x_axis_key option:selected').data("range");
    xScale.domain(xDomain).nice();
    // xScale.domain([
    //   d3.min( dat.data, function(d) { return d[0];}),
    //   d3.max( dat.data, function(d) { return d[0];})
    // ]).nice();

    var yScale = d3.scale.linear().range([height, 0]);
    var yDomain = $('select#y_axis_key option:selected').data("range");
    yScale.domain(yDomain).nice();
    // yScale.domain([
    //   d3.min( dat.data, function(d) { return d[1];}),
    //   d3.max( dat.data, function(d) { return d[1];})
    // ]).nice();

    var colorScale;
    domains = $('select#result option:selected').data("domain");
    if( domains ) {
      colorScale = d3.scale.linear().range(["#0041ff", "#ff2800"])
      colorScale.domain(domains).nice();
    }

    function draw_color_map(g) {
      var scale = d3.scale.linear().domain([0.0, 1.0]).range(colorScale.range());
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
        .text( colorScale.domain()[1] );
      g.append("text")
        .attr({x: 30.0, y: 140.0, dx: "0.2em", dy: "-0.3em"})
        .style("text-anchor", "begin")
        .text( colorScale.domain()[0] );
    }
    colorMapG.selectAll("text").remove();
    colorMapG.selectAll("rect").remove();
    if( colorScale ) { draw_color_map(colorMapG); }

    function draw_axes(xlabel, ylabel) {
      d3.selectAll("g.axis").remove();
      // X-Axis
      var xAxis = d3.svg.axis()
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
      var yAxis = d3.svg.axis()
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

    function draw_voronoi_heat_map() {
      var vertices = dat.data.map(function(v) { return [xScale(v[0]), yScale(v[1])]; })
      var voronoi = d3.geom.voronoi()
        .clipExtent([[0, 0], [width, height]]);
      var path = svg.append("g")
        .attr("id", "voronoi-group")
        .selectAll("path")
        .data(voronoi(vertices));
      path.enter().append("path")
        .style("fill", function(d, i) { return colorScale(dat.data[i][2]);})
        .attr("d", function(d) { return "M" + d.join("L") + "Z"; })
        .style("fill-opacity", 0.7)
        .style("stroke", "none");
    }
    try {
      d3.select("g#voronoi-group").remove();
      if( colorScale ) { draw_voronoi_heat_map(); }
      // Voronoi division fails when duplicate points are included.
      // In that case, just ignore creating voronoi heatmap and continue plotting.
    } catch(e) {
      console.log(e);
    }

    function draw_points() {
      var tooltip = d3.select("#plot-tooltip");
      var mapped = dat.data.map(function(v) {
        return {
          x: v[0], y: v[1],
          average: v[2], error: v[3], psid: v[4]
        };
      });
      var point = svg.selectAll("circle")
        .data(mapped);
      point.exit().remove();
      point.enter().append("circle");
      point
        .attr("cx", function(d) { return xScale(d.x);})
        .attr("cy", function(d) { return yScale(d.y);})
        .style("fill", function(d) {
          if( colorScale) { return colorScale(d.average); }
          else { return "black"; }
        })
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
        .on("click", function(d) {
          set_current_ps(d.psid);
        })
        .on("dblclick", function(d) {
          var ps_url = $('#plot').data('ps-url').replace('PSID', d.psid);
          // open a link in a background window
          window.open(ps_url, '_blank');
        });
    }
    draw_points();
  })
  .on("error", function() { console.log("error"); /*progress.remove(); */})
  .get();
  // progress.on("mousedown", function(){
  //   xhr.abort();
  //   row.remove();
  // });
}

function add_pc_plot(url, current_ps_id) {
  var margin = {top: 100, right: 100, bottom: 100, left: 100};
  var width = 560;
  var height = 460;

  var plot_region = d3.select("#pc-plot");

  var svg = plot_region.insert("svg")
    .attr({
      "width": width + margin.left + margin.right,
      "height": height + margin.top + margin.bottom,
      "id": "pc-plot-svg"
    })
    .append("g")
    .attr({
      "transform": "translate(" + margin.left + "," + margin.top + ")",
      "id": "plot-group"
    });

  var dimensions = [];
  var yScales = {};
  function set_scales_and_dimensions() {
    $('select#x_axis_key option').each(function() {
      var extent = $(this).data("range");
      var key = $(this).text();
      var scale = d3.scale.linear().domain(extent).range([height, 0]).nice();
      yScales[key] = scale;
      dimensions.push(key);
    });
  };
  set_scales_and_dimensions();

  var xScale = d3.scale.ordinal().rangePoints([0,width], 1).domain( dimensions );

  function path_generater(d) {
    var points = dimensions.map( function(p) {
      return [ xScale(p), yScales[p]( d[p] ) ]
    })
  }

  var g = svg.selectAll(".dimension")
    .data(dimensions)
    .enter().append("svg:g")
    .attr("class", "dimension")
    .attr("transform", function(d) { return "translate(" + xScale(d) + ")"; });

  var axis = d3.svg.axis().orient("left");
  g.append("svg:g")
    .attr("class", "pcp-axis")
    .each(function(d) {
      d3.select(this).call( axis.scale(yScales[d]) );
    })
    .append("svg:text")
    .attr("text-anchor", "middle")
    .attr("y", -9)
    .text(String); // set text to the data values
};
