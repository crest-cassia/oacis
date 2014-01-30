function draw_explorer(url, parameter_set_base_url, current_ps_id) {
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

    var xScale = d3.scale.linear().range([0, width]);
    var yScale = d3.scale.linear().range([height, 0]);
    var colorScale = d3.scale.linear().range(["#0041ff", "#ff2800"])

    xScale.domain([
      d3.min( dat.data, function(d) { return d[0];}),
      d3.max( dat.data, function(d) { return d[0];})
    ]).nice();
    yScale.domain([
      d3.min( dat.data, function(d) { return d[1];}),
      d3.max( dat.data, function(d) { return d[1];})
    ]).nice();
    colorScale.domain([
      d3.min( dat.data, function(d) { return d[2];}),
      d3.max( dat.data, function(d) { return d[2];})
    ]).nice();

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
    draw_color_map(colorMapG);

    function draw_axes(xlabel, ylabel) {
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
      var path = svg.append("g").selectAll("path")
        .data(voronoi(vertices));
      path.enter().append("path")
        .style("fill", function(d, i) { return colorScale(dat.data[i][2]);})
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

    function draw_points() {
      var tooltip = d3.select("#plot-tooltip");
      var mapped = dat.data.map(function(v) {
        return {
          x: v[0], y: v[1],
          average: v[2], error: v[3], psid: v[4]
        };
      });
      var point = svg.selectAll("circle")
        .data(mapped).enter();
      point.append("circle")
        .attr("cx", function(d) { return xScale(d.x);})
        .attr("cy", function(d) { return yScale(d.y);})
        .style("fill", function(d) { return colorScale(d.average);})
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
