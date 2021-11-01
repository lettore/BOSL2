//////////////////////////////////////////////////////////////////////
// LibFile: geometry.scad
//   Perform calculations on lines, polygons, planes and circles, including
//   normals, intersections of objects, distance between objects, and tangent lines.
//   Throughout this library, lines can be treated as either unbounded lines, as rays with
//   a single endpoint or as segments, bounded by endpoints at both ends.  
// Includes:
//   include <BOSL2/std.scad>
//////////////////////////////////////////////////////////////////////


// Section: Lines, Rays, and Segments

// Function: is_point_on_line()
// Usage:
//   pt = is_point_on_line(point, line, [bounded], [eps]);
// Topics: Geometry, Points, Segments
// Description:
//   Determine if the point is on the line segment, ray or segment defined by the two between two points.
//   Returns true if yes, and false if not.  If bounded is set to true it specifies a segment, with
//   both lines bounded at the ends.  Set bounded to `[true,false]` to get a ray.  You can use
//   the shorthands RAY and SEGMENT to set bounded.  
// Arguments:
//   point = The point to test.
//   line = Array of two points defining the line, ray, or segment to test against.
//   bounded = boolean or list of two booleans defining endpoint conditions for the line. If false treat the line as an unbounded line.  If true treat it as a segment.  If [true,false] treat as a ray, based at the first endpoint.  Default: false
//   eps = Tolerance in geometric comparisons.  Default: `EPSILON` (1e-9)
function is_point_on_line(point, line, bounded=false, eps=EPSILON) =
    assert(is_finite(eps) && (eps>=0), "The tolerance should be a non-negative value." )
    assert(is_vector(point), "Point must be a vector")
    assert(_valid_line(line, len(point),eps),"Given line is not valid")
    _is_point_on_line(point, line, bounded,eps);

function _is_point_on_line(point, line, bounded=false, eps=EPSILON) =
    let( 
        v1 = (line[1]-line[0]),
        v0 = (point-line[0]),
        t  = v0*v1/(v1*v1),
        bounded = force_list(bounded,2)
    ) 
    abs(cross(v0,v1))<eps*norm(v1) 
    && (!bounded[0] || t>=-eps) 
    && (!bounded[1] || t<1+eps) ;

function xis_point_on_line(point, line, bounded=false, eps=EPSILON) =
    assert( is_finite(eps) && (eps>=0), "The tolerance should be a non-negative value." )
    point_line_distance(point, line, bounded)<eps;


///Internal - distance from point `d` to the line passing through the origin with unit direction n
///_dist2line works for any dimension
function _dist2line(d,n) = norm(d-(d * n) * n);


///Internal
function _valid_line(line,dim,eps=EPSILON) =
    is_matrix(line,2,dim)
    && norm(line[1]-line[0])>eps*max(norm(line[1]),norm(line[0]));

//Internal
function _valid_plane(p, eps=EPSILON) = is_vector(p,4) && ! approx(norm(p),0,eps);


/// Internal Function: point_left_of_line2d()
/// Usage:
///   pt = point_left_of_line2d(point, line);
/// Topics: Geometry, Points, Lines
/// Description:
///   Return >0 if point is left of the line defined by `line`.
///   Return =0 if point is on the line.
///   Return <0 if point is right of the line.
/// Arguments:
///   point = The point to check position of.
///   line  = Array of two points forming the line segment to test against.
function _point_left_of_line2d(point, line) =
    assert( is_vector(point,2) && is_vector(line*point, 2), "Improper input." )
    cross(line[0]-point, line[1]-line[0]);


// Function: is_collinear()
// Usage:
//   test = is_collinear(a, [b, c], [eps]);
// Topics: Geometry, Points, Collinearity
// Description:
//   Returns true if the points `a`, `b` and `c` are co-linear or if the list of points `a` is collinear.
// Arguments:
//   a = First point or list of points.
//   b = Second point or undef; it should be undef if `c` is undef
//   c = Third point or undef.
//   eps = Tolerance in geometric comparisons.  Default: `EPSILON` (1e-9)
function is_collinear(a, b, c, eps=EPSILON) =
    assert( is_path([a,b,c],dim=undef)
            || ( is_undef(b) && is_undef(c) && is_path(a,dim=undef) ),
            "Input should be 3 points or a list of points with same dimension.")
    assert( is_finite(eps) && (eps>=0), "The tolerance should be a non-negative value." )
    let( points = is_def(c) ? [a,b,c]: a )
    len(points)<3 ? true :
    noncollinear_triple(points,error=false,eps=eps) == [];


// Function: point_line_distance()
// Usage:
//   pt = point_line_distance(line, pt, bounded);
// Topics: Geometry, Points, Lines, Distance
// Description:
//   Finds the shortest distance from the point `pt` to the specified line, segment or ray.
//   The bounded parameter specifies the whether the endpoints give a ray or segment.
//   By default assumes an unbounded line.  
// Arguments:
//   line = A list of two points defining a line.
//   pt = A point to find the distance of from the line.
//   bounded = a boolean or list of two booleans specifiying whether each end is bounded.  Default: false
// Example:
//   dist1 = point_line_distance([3,8], [[-10,0], [10,0]]);  // Returns: 8
//   dist2 = point_line_distance([3,8], [[-10,0], [10,0]],SEGMENT);  // Returns: 8
//   dist3 = point_line_distance([14,3], [[-10,0], [10,0]],SEGMENT);  // Returns: 5
function point_line_distance(pt, line, bounded=false) =
    assert(is_bool(bounded) || is_bool_list(bounded,2), "\"bounded\" is invalid")
    assert( _valid_line(line) && is_vector(pt,len(line[0])),
            "Invalid line, invalid point or incompatible dimensions." )
    bounded == LINE ? _dist2line(pt-line[0],unit(line[1]-line[0]))
                    : norm(pt-line_closest_point(line,pt,bounded));

                           
// Function: segment_distance()
// Usage:
//   dist = segment_distance(seg1, seg2, [eps]);
// Topics: Geometry, Segments, Distance
// See Also: convex_collision(), convex_distance()
// Description:
//   Returns the closest distance of the two given line segments.
// Arguments:
//   seg1 = The list of two points representing the first line segment to check the distance of.
//   seg2 = The list of two points representing the second line segment to check the distance of.
//   eps = tolerance for point comparisons
// Example:
//   dist = segment_distance([[-14,3], [-15,9]], [[-10,0], [10,0]]);  // Returns: 5
//   dist2 = segment_distance([[-5,5], [5,-5]], [[-10,3], [10,-3]]);  // Returns: 0
function segment_distance(seg1, seg2,eps=EPSILON) =
    assert( is_matrix(concat(seg1,seg2),4), "Inputs should be two valid segments." )
    convex_distance(seg1,seg2,eps);


// Function: line_normal()
// Usage:
//   vec = line_normal([P1,P2])
//   vec = line_normal(p1,p2)
// Topics: Geometry, Lines
// Description:
//   Returns the 2D normal vector to the given 2D line. This is otherwise known as the perpendicular vector counter-clockwise to the given ray.
// Arguments:
//   p1 = First point on 2D line.
//   p2 = Second point on 2D line.
// Example(2D):
//   p1 = [10,10];
//   p2 = [50,30];
//   n = line_normal(p1,p2);
//   stroke([p1,p2], endcap2="arrow2");
//   color("green") stroke([p1,p1+10*n], endcap2="arrow2");
//   color("blue") move_copies([p1,p2]) circle(d=2, $fn=12);
function line_normal(p1,p2) =
    is_undef(p2)
      ? assert( len(p1)==2 && !is_undef(p1[1]) , "Invalid input." )
        line_normal(p1[0],p1[1])
      : assert( _valid_line([p1,p2],dim=2), "Invalid line." )
        unit([p1.y-p2.y,p2.x-p1.x]);


// 2D Line intersection from two segments.
// This function returns [p,t,u] where p is the intersection point of
// the lines defined by the two segments, t is the proportional distance
// of the intersection point along s1, and u is the proportional distance
// of the intersection point along s2.  The proportional values run over
// the range of 0 to 1 for each segment, so if it is in this range, then
// the intersection lies on the segment.  Otherwise it lies somewhere on
// the extension of the segment.  If lines are parallel or coincident then
// it returns undef.

function _general_line_intersection(s1,s2,eps=EPSILON) =
    let(
        denominator = cross(s1[0]-s1[1],s2[0]-s2[1])
    )
    approx(denominator,0,eps=eps) ? undef :
    let(
        t = cross(s1[0]-s2[0],s2[0]-s2[1]) / denominator,
        u = cross(s1[0]-s2[0],s1[0]-s1[1]) / denominator
    )
    [s1[0]+t*(s1[1]-s1[0]), t, u];
                  

// Function: line_intersection()
// Usage:
//    pt = line_intersection(line1, line2, [bounded1], [bounded2], [bounded=], [eps=]);
// Description:
//    Returns the intersection point of any two 2D lines, segments or rays.  Returns undef
//    if they do not intersect.  You specify a line by giving two distinct points on the
//    line.  You specify rays or segments by giving a pair of points and indicating
//    bounded[0]=true to bound the line at the first point, creating rays based at l1[0] and l2[0],
//    or bounded[1]=true to bound the line at the second point, creating the reverse rays bounded
//    at l1[1] and l2[1].  If bounded=[true, true] then you have segments defined by their two
//    endpoints.  By using bounded1 and bounded2 you can mix segments, rays, and lines as needed.
//    You can set the bounds parameters to true as a shorthand for [true,true] to sepcify segments.
// Arguments:
//    line1 = List of two points in 2D defining the first line, segment or ray
//    line2 = List of two points in 2D defining the second line, segment or ray
//    bounded1 = boolean or list of two booleans defining which ends are bounded for line1.  Default: [false,false]
//    bounded2 = boolean or list of two booleans defining which ends are bounded for line2.  Default: [false,false]
//    ---
//    bounded = boolean or list of two booleans defining which ends are bounded for both lines.  The bounded1 and bounded2 parameters override this if both are given.
//    eps = tolerance for geometric comparisons.  Default: `EPSILON` (1e-9)
// Example(2D):  The segments do not intersect but the lines do in this example. 
//    line1 = 10*[[9, 4], [5, 7]];
//    line2 = 10*[[2, 3], [6, 5]];
//    stroke(line1, endcaps="arrow2");
//    stroke(line2, endcaps="arrow2");
//    isect = line_intersection(line1, line2);
//    color("red") translate(isect) circle(r=1,$fn=12);
// Example(2D): Specifying a ray and segment using the shorthand variables.
//    line1 = 10*[[0, 2], [4, 7]];
//    line2 = 10*[[10, 4], [3, 4]];
//    stroke(line1);
//    stroke(line2, endcap2="arrow2");
//    isect = line_intersection(line1, line2, SEGMENT, RAY);
//    color("red") translate(isect) circle(r=1,$fn=12);
// Example(2D): Here we use the same example as above, but specify two segments using the bounded argument.
//    line1 = 10*[[0, 2], [4, 7]];
//    line2 = 10*[[10, 4], [3, 4]];
//    stroke(line1);
//    stroke(line2);
//    isect = line_intersection(line1, line2, bounded=true);  // Returns undef
function line_intersection(line1, line2, bounded1, bounded2, bounded, eps=EPSILON) =
    assert( is_finite(eps) && (eps>=0), "The tolerance should be a non-negative value." )
    assert( _valid_line(line1,dim=2,eps=eps), "First line invalid")
    assert( _valid_line(line2,dim=2,eps=eps), "Second line invalid")
    assert( is_undef(bounded) || is_bool(bounded) || is_bool_list(bounded,2), "Invalid value for \"bounded\"")
    assert( is_undef(bounded1) || is_bool(bounded1) || is_bool_list(bounded1,2), "Invalid value for \"bounded1\"")
    assert( is_undef(bounded2) || is_bool(bounded2) || is_bool_list(bounded2,2), "Invalid value for \"bounded2\"")
    let(isect = _general_line_intersection(line1,line2,eps=eps))
    is_undef(isect) ? undef :
    let(
        bounded1 = force_list(first_defined([bounded1,bounded,false]),2),
        bounded2 = force_list(first_defined([bounded2,bounded,false]),2),
        good =  (!bounded1[0] || isect[1]>=0-eps)
             && (!bounded1[1] || isect[1]<=1+eps)
             && (!bounded2[0] || isect[2]>=0-eps)
             && (!bounded2[1] || isect[2]<=1+eps)
    )
    good ? isect[0] : undef;
    

// Function: line_closest_point()
// Usage:
//   pt = line_closest_point(line, pt, [bounded]);
// Topics: Geometry, Lines, Distance
// Description:
//   Returns the point on the given line, segment or ray that is closest to the given point `pt`.
//   The inputs `line` and `pt` args should be of the same dimension.  The parameter bounded indicates
//   whether the points of `line` should be treated as endpoints. 
// Arguments:
//   line = A list of two points that are on the unbounded line.
//   pt = The point to find the closest point on the line to.
//   bounded = boolean or list of two booleans indicating that the line is bounded at that end.  Default: [false,false]
// Example(2D):
//   line = [[-30,0],[30,30]];
//   pt = [-32,-10];
//   p2 = line_closest_point(line,pt);
//   stroke(line, endcaps="arrow2");
//   color("blue") translate(pt) circle(r=1,$fn=12);
//   color("red") translate(p2) circle(r=1,$fn=12);
// Example(2D):  If the line is bounded on the left you get the endpoint instead
//   line = [[-30,0],[30,30]];
//   pt = [-32,-10];
//   p2 = line_closest_point(line,pt,bounded=[true,false]);
//   stroke(line, endcap2="arrow2");
//   color("blue") translate(pt) circle(r=1,$fn=12);
//   color("red") translate(p2) circle(r=1,$fn=12);
// Example(2D):  In this case it doesn't matter how bounded is set.  Using SEGMENT is the most restrictive option. 
//   line = [[-30,0],[30,30]];
//   pt = [-5,0];
//   p2 = line_closest_point(line,pt,SEGMENT);
//   stroke(line);
//   color("blue") translate(pt) circle(r=1,$fn=12);
//   color("red") translate(p2) circle(r=1,$fn=12);
// Example(2D):  The result here is the same for a line or a ray. 
//   line = [[-30,0],[30,30]];
//   pt = [40,25];
//   p2 = line_closest_point(line,pt,RAY);
//   stroke(line, endcap2="arrow2");
//   color("blue") translate(pt) circle(r=1,$fn=12);
//   color("red") translate(p2) circle(r=1,$fn=12);
// Example(2D):  But with a segment we get a different result
//   line = [[-30,0],[30,30]];
//   pt = [40,25];
//   p2 = line_closest_point(line,pt,SEGMENT);
//   stroke(line);
//   color("blue") translate(pt) circle(r=1,$fn=12);
//   color("red") translate(p2) circle(r=1,$fn=12);
// Example(2D): The shorthand RAY uses the first point as the base of the ray.  But you can specify a reversed ray directly, and in this case the result is the same as the result above for the segment.
//   line = [[-30,0],[30,30]];
//   pt = [40,25];
//   p2 = line_closest_point(line,pt,[false,true]);
//   stroke(line,endcap1="arrow2");
//   color("blue") translate(pt) circle(r=1,$fn=12);
//   color("red") translate(p2) circle(r=1,$fn=12);
// Example(FlatSpin,VPD=200,VPT=[0,0,15]): A 3D example
//   line = [[-30,-15,0],[30,15,30]];
//   pt = [5,5,5];
//   p2 = line_closest_point(line,pt);
//   stroke(line, endcaps="arrow2");
//   color("blue") translate(pt) sphere(r=1,$fn=12);
//   color("red") translate(p2) sphere(r=1,$fn=12);
function line_closest_point(line, pt, bounded=false) =
    assert(_valid_line(line), "Invalid line")
    assert(is_vector(pt, len(line[0])), "Invalid point or incompatible dimensions.")
    assert(is_bool(bounded) || is_bool_list(bounded,2), "Invalid value for \"bounded\"")
    let(
        bounded = force_list(bounded,2)
    )
    bounded==[false,false] ?
          let( n = unit( line[0]- line[1]) )
          line[1] + ((pt- line[1]) * n) * n
    : bounded == [true,true] ?
          pt + _closest_s1([line[0]-pt, line[1]-pt])[0]
    : 
          let(
               ray = bounded==[true,false] ? line : reverse(line),
               seglen = norm(ray[1]-ray[0]),
               segvec = (ray[1]-ray[0])/seglen,
               projection = (pt-ray[0]) * segvec
          )
          projection<=0 ? ray[0] :
                          ray[0] + projection*segvec;
            

// Function: line_from_points()
// Usage:
//   line = line_from_points(points, [fast], [eps]);
// Topics: Geometry, Lines, Points
// Description:
//   Given a list of 2 or more collinear points, returns a line containing them.
//   If `fast` is false and the points are coincident or non-collinear, then `undef` is returned.
//   if `fast` is true, then the collinearity test is skipped and a line passing through 2 distinct arbitrary points is returned.
// Arguments:
//   points = The list of points to find the line through.
//   fast = If true, don't verify that all points are collinear.  Default: false
//   eps = How much variance is allowed in testing each point against the line.  Default: `EPSILON` (1e-9)
function line_from_points(points, fast=false, eps=EPSILON) =
    assert( is_path(points), "Invalid point list." )
    assert( is_finite(eps) && (eps>=0), "The tolerance should be a non-negative value." )
    let( pb = furthest_point(points[0],points) )
    norm(points[pb]-points[0])<eps*max(norm(points[pb]),norm(points[0])) ? undef :
    fast || is_collinear(points)
      ? [points[pb], points[0]]
      : undef;



// Section: Planes


// Function: is_coplanar()
// Usage:
//   test = is_coplanar(points,[eps]);
// Topics: Geometry, Coplanarity
// Description:
//   Returns true if the given 3D points are non-collinear and are on a plane.
// Arguments:
//   points = The points to test.
//   eps = Tolerance in geometric comparisons.  Default: `EPSILON` (1e-9)
function is_coplanar(points, eps=EPSILON) =
    assert( is_path(points,dim=3) , "Input should be a list of 3D points." )
    assert( is_finite(eps) && eps>=0, "The tolerance should be a non-negative value." )
    len(points)<=2 ? false
      : let( ip = noncollinear_triple(points,error=false,eps=eps) )
        ip == [] ? false :
        let( plane  = plane3pt(points[ip[0]],points[ip[1]],points[ip[2]]) )
        _pointlist_greatest_distance(points,plane) < eps;



// Function: plane3pt()
// Usage:
//   plane = plane3pt(p1, p2, p3);
// Topics: Geometry, Planes
// Description:
//   Generates the normalized cartesian equation of a plane from three 3d points.
//   Returns [A,B,C,D] where Ax + By + Cz = D is the equation of a plane.
//   Returns undef, if the points are collinear.
// Arguments:
//   p1 = The first point on the plane.
//   p2 = The second point on the plane.
//   p3 = The third point on the plane.
function plane3pt(p1, p2, p3) =
    assert( is_path([p1,p2,p3],dim=3) && len(p1)==3,
            "Invalid points or incompatible dimensions." )
    let(
        crx = cross(p3-p1, p2-p1),
        nrm = norm(crx)
    ) approx(nrm,0) ? undef :
    concat(crx, crx*p1)/nrm;


// Function: plane3pt_indexed()
// Usage:
//   plane = plane3pt_indexed(points, i1, i2, i3);
// Topics: Geometry, Planes
// Description:
//   Given a list of 3d points, and the indices of three of those points,
//   generates the normalized cartesian equation of a plane that those points all
//   lie on. If the points are not collinear, returns [A,B,C,D] where Ax+By+Cz=D is the equation of a plane.
//   If they are collinear, returns [].
// Arguments:
//   points = A list of points.
//   i1 = The index into `points` of the first point on the plane.
//   i2 = The index into `points` of the second point on the plane.
//   i3 = The index into `points` of the third point on the plane.
function plane3pt_indexed(points, i1, i2, i3) =
    assert( is_vector([i1,i2,i3]) && min(i1,i2,i3)>=0 && is_list(points) && max(i1,i2,i3)<len(points),
            "Invalid or out of range indices." )
    assert( is_path([points[i1], points[i2], points[i3]],dim=3),
            "Improper points or improper dimensions." )
    let(
        p1 = points[i1],
        p2 = points[i2],
        p3 = points[i3]
    ) plane3pt(p1,p2,p3);


// Function: plane_from_normal()
// Usage:
//   plane = plane_from_normal(normal, [pt])
// Topics: Geometry, Planes
// Description:
//   Returns a plane defined by a normal vector and a point.  If you omit `pt` you will get a plane
//   passing through the origin.  
// Arguments:
//   normal = Normal vector to the plane to find.
//   pt = Point 3D on the plane to find.
// Example:
//   plane_from_normal([0,0,1], [2,2,2]);  // Returns the xy plane passing through the point (2,2,2)
function plane_from_normal(normal, pt=[0,0,0]) =
    assert( is_matrix([normal,pt],2,3) && !approx(norm(normal),0),
            "Inputs `normal` and `pt` should be 3d vectors/points and `normal` cannot be zero." )
    concat(normal, normal*pt) / norm(normal);


// Eigenvalues for a 3x3 symmetrical matrix in decreasing order
// Based on: https://en.wikipedia.org/wiki/Eigenvalue_algorithm
function _eigenvals_symm_3(M) =
  let( p1 = pow(M[0][1],2) + pow(M[0][2],2) + pow(M[1][2],2) )
  (p1<EPSILON)
  ? -sort(-[ M[0][0], M[1][1], M[2][2] ]) //  diagonal matrix: eigenvals in decreasing order
  : let(  q  = (M[0][0]+M[1][1]+M[2][2])/3,
          B  = (M - q*ident(3)),
          dB = [B[0][0], B[1][1], B[2][2]],
          p2 = dB*dB + 2*p1,
          p  = sqrt(p2/6),
          r  = det3(B/p)/2,
          ph = acos(constrain(r,-1,1))/3,
          e1 = q + 2*p*cos(ph),
          e3 = q + 2*p*cos(ph+120),
          e2 = 3*q - e1 - e3 )
    [ e1, e2, e3 ];


// the i-th normalized eigenvector of a 3x3 symmetrical matrix M from its eigenvalues
// using Cayley–Hamilton theorem according to:
// https://en.wikipedia.org/wiki/Eigenvalue_algorithm
function _eigenvec_symm_3(M,evals,i=0) =
    let(
        I = ident(3),
        A = (M - evals[(i+1)%3]*I) * (M - evals[(i+2)%3]*I) ,
        k = max_index( [for(i=[0:2]) norm(A[i]) ])
    )
    norm(A[k])<EPSILON ? I[k] : A[k]/norm(A[k]);


// finds the eigenvector corresponding to the smallest eigenvalue of the covariance matrix of a pointlist
// returns the mean of the points, the eigenvector and the greatest eigenvalue
function _covariance_evec_eval(points) =
    let(  pm    = sum(points)/len(points), // mean point
          Y     = [ for(i=[0:len(points)-1]) points[i] - pm ],
          M     = transpose(Y)*Y ,     // covariance matrix
          evals = _eigenvals_symm_3(M), // eigenvalues in decreasing order
          evec  = _eigenvec_symm_3(M,evals,i=2) )
    [pm, evec, evals[0] ];
    

// Function: plane_from_points()
// Usage:
//   plane = plane_from_points(points, [fast], [eps]);
// Topics: Geometry, Planes, Points
// See Also: plane_from_polygon()
// Description:
//   Given a list of 3 or more coplanar 3D points, returns the coefficients of the normalized cartesian equation of a plane,
//   that is [A,B,C,D] where Ax+By+Cz=D is the equation of the plane and norm([A,B,C])=1.
//   If `fast` is false and the points in the list are collinear or not coplanar, then `undef` is returned.
//   If `fast` is true, the polygon coplanarity check is skipped and a best fitting plane is returned.
//   It differs from `plane_from_polygon` as the plane normal is independent of the point order. It is faster, though.
// Arguments:
//   points = The list of points to find the plane of.
//   fast = If true, don't verify the point coplanarity.  Default: false
//   eps = Tolerance in geometric comparisons.  Default: `EPSILON` (1e-9)
// Example(3D):
//   points = rot(45, v=[-0.3,1,0], p=path3d(random_points(25,2,scale=55,seed=47), 70));
//   plane = plane_from_points(points);
//   #move_copies(points)sphere(d=3);
//   cp = mean(points);
//   move(cp) rot(from=UP,to=plane_normal(plane)) anchor_arrow(50);
function plane_from_points(points, fast=false, eps=EPSILON) =
    assert( is_path(points,dim=3), "Improper 3d point list." )
    assert( is_finite(eps) && (eps>=0), "The tolerance should be a non-negative value." )
    len(points) == 3
      ? plane3pt(points[0],points[1],points[2]) 
      : let(
            covmix = _covariance_evec_eval(points),
            pm     = covmix[0],
            evec   = covmix[1],
            eval0  = covmix[2],
            plane  = [ each evec, pm*evec]
        )
        !fast && _pointlist_greatest_distance(points,plane)>eps*eval0 ? undef :
        plane ;


// Function: plane_from_polygon()
// Usage:
//   plane = plane_from_polygon(points, [fast], [eps]);
// Topics: Geometry, Planes, Polygons
// See Also: plane_from_points()
// Description:
//   Given a 3D planar polygon, returns the normalized cartesian equation of its plane.
//   Returns [A,B,C,D] where Ax+By+Cz=D is the equation of the plane where norm([A,B,C])=1.
//   If not all the points in the polygon are coplanar, then [] is returned.
//   If `fast` is false and the points in the list are collinear or not coplanar, then `undef` is returned.
//   if `fast` is true, then the coplanarity test is skipped and a plane passing through 3 non-collinear arbitrary points is returned.
// Arguments:
//   poly = The planar 3D polygon to find the plane of.
//   fast = If true, doesn't verify that all points in the polygon are coplanar.  Default: false
//   eps = Tolerance in geometric comparisons.  Default: `EPSILON` (1e-9)
// Example(3D):
//   xyzpath = rot(45, v=[0,1,0], p=path3d(star(n=5,step=2,d=100), 70));
//   plane = plane_from_polygon(xyzpath);
//   #stroke(xyzpath,closed=true,width=3);
//   cp = centroid(xyzpath);
//   move(cp) rot(from=UP,to=plane_normal(plane)) anchor_arrow(45);
function plane_from_polygon(poly, fast=false, eps=EPSILON) =
    assert( is_path(poly,dim=3), "Invalid polygon." )
    assert( is_finite(eps) && (eps>=0), "The tolerance should be a non-negative value." )
    let(
        poly_normal = polygon_normal(poly)
    )
    is_undef(poly_normal) ? undef :
    let(
        plane = plane_from_normal(poly_normal, poly[0])
    )
    fast? plane: are_points_on_plane(poly, plane, eps=eps)? plane: undef;


// Function: plane_normal()
// Usage:
//   vec = plane_normal(plane);
// Topics: Geometry, Planes
// Description:
//   Returns the unit length normal vector for the given plane.
// Arguments:
//   plane = The `[A,B,C,D]` plane definition where `Ax+By+Cz=D` is the formula of the plane.
function plane_normal(plane) =
    assert( _valid_plane(plane), "Invalid input plane." )
    unit([plane.x, plane.y, plane.z]);


// Function: plane_offset()
// Usage:
//   d = plane_offset(plane);
// Topics: Geometry, Planes
// Description:
//   Returns coeficient D of the normalized plane equation `Ax+By+Cz=D`, or the scalar offset of the plane from the origin.
//   This value may be negative.
//   The absolute value of this coefficient is the distance of the plane from the origin.
// Arguments:
//   plane = The `[A,B,C,D]` plane definition where `Ax+By+Cz=D` is the formula of the plane.
function plane_offset(plane) =
    assert( _valid_plane(plane), "Invalid input plane." )
    plane[3]/norm([plane.x, plane.y, plane.z]);



// Returns [POINT, U] if line intersects plane at one point, where U is zero at line[0] and 1 at line[1]
// Returns [LINE, undef] if the line is on the plane.
// Returns undef if line is parallel to, but not on the given plane.
function _general_plane_line_intersection(plane, line, eps=EPSILON) =
    let(
        a = plane*[each line[0],-1],         //  evaluation of the plane expression at line[0]
        b = plane*[each(line[1]-line[0]),0]  // difference between the plane expression evaluation at line[1] and at line[0]
    )
    approx(b,0,eps)                          // is  (line[1]-line[0]) "parallel" to the plane ?
      ? approx(a,0,eps)                      // is line[0] on the plane ?
        ? [line,undef]                       // line is on the plane
        : undef                              // line is parallel but not on the plane
      : [ line[0]-a/b*(line[1]-line[0]), -a/b ];


/// Internal Function: normalize_plane()
// Usage:
//   nplane = normalize_plane(plane);
/// Topics: Geometry, Planes
// Description:
//   Returns a new representation [A,B,C,D] of `plane` where norm([A,B,C]) is equal to one.
function _normalize_plane(plane) =
    assert( _valid_plane(plane), str("Invalid plane. ",plane ) )
    plane/norm(point3d(plane));


// Function: plane_line_intersection()
// Usage:
//   pt = plane_line_intersection(plane, line, [bounded], [eps]);
// Topics: Geometry, Planes, Lines, Intersection
// Description:
//   Takes a line, and a plane [A,B,C,D] where the equation of that plane is `Ax+By+Cz=D`.
//   If `line` intersects `plane` at one point, then that intersection point is returned.
//   If `line` lies on `plane`, then the original given `line` is returned.
//   If `line` is parallel to, but not on `plane`, then undef is returned.
// Arguments:
//   plane = The [A,B,C,D] values for the equation of the plane.
//   line = A list of two distinct 3D points that are on the line.
//   bounded = If false, the line is considered unbounded.  If true, it is treated as a bounded line segment.  If given as `[true, false]` or `[false, true]`, the boundedness of the points are specified individually, allowing the line to be treated as a half-bounded ray.  Default: false (unbounded)
//   eps = Tolerance in geometric comparisons.  Default: `EPSILON` (1e-9)
function plane_line_intersection(plane, line, bounded=false, eps=EPSILON) =
    assert( is_finite(eps) && eps>=0, "The tolerance should be a positive number." )
    assert(_valid_plane(plane,eps=eps) && _valid_line(line,dim=3,eps=eps), "Invalid plane and/or 3d line.")
    assert(is_bool(bounded) || is_bool_list(bounded,2), "Invalid bound condition.")
    let(
        bounded = is_list(bounded)? bounded : [bounded, bounded],
        res = _general_plane_line_intersection(plane, line, eps=eps)
    ) is_undef(res) ? undef :
    is_undef(res[1]) ? res[0] :
    bounded[0] && res[1]<0 ? undef :
    bounded[1] && res[1]>1 ? undef :
    res[0];


// Function: polygon_line_intersection()
// Usage:
//   pt = polygon_line_intersection(poly, line, [bounded], [nonzero], [eps]);
// Topics: Geometry, Polygons, Lines, Intersection
// Description:
//   Takes a possibly bounded line, and a 2D or 3D planar polygon, and finds their intersection.
//   If the line does not intersect the polygon then `undef` returns `undef`.  
//   In 3D if the line is not on the plane of the polygon but intersects it then you get a single intersection point.
//   Otherwise the polygon and line are in the same plane, or when your input is 2D, ou will get a list of segments and 
//   single point lists.  Use `is_vector` to distinguish these two cases.
//    .
//   In the 2D case, when single points are in the intersection they appear on the segment list as lists of a single point
//   (like single point segments) so a single point intersection in 2D has the form `[[[x,y,z]]]` as compared
//   to a single point intersection in 3D which has the form `[x,y,z]`.  You can identify whether an entry in the
//   segment list is a true segment by checking its length, which will be 2 for a segment and 1 for a point.  
// Arguments:
//   poly = The 3D planar polygon to find the intersection with.
//   line = A list of two distinct 3D points on the line.
//   bounded = If false, the line is considered unbounded.  If true, it is treated as a bounded line segment.  If given as `[true, false]` or `[false, true]`, the boundedness of the points are specified individually, allowing the line to be treated as a half-bounded ray.  Default: false (unbounded)
//   nonzero = set to true to use the nonzero rule for determining it points are in a polygon.  See point_in_polygon.  Default: false.
//   eps = Tolerance in geometric comparisons.  Default: `EPSILON` (1e-9)
// Example(3D): The line intersects the 3d hexagon in a single point. 
//   hex = zrot(140,p=rot([-45,40,20],p=path3d(hexagon(r=15))));
//   line = [[5,0,-13],[-3,-5,13]];
//   isect = polygon_line_intersection(hex,line);
//   stroke(hex,closed=true);
//   stroke(line);
//   color("red")move(isect)sphere(r=1,$fn=12);
// Example(2D): In 2D things are more complicated.  The output is a list of intersection parts, in the simplest case a single segment.
//   hex = hexagon(r=15);
//   line = [[-20,10],[25,-7]];
//   isect = polygon_line_intersection(hex,line);
//   stroke(hex,closed=true);
//   stroke(line,endcaps="arrow2");
//   color("red")
//     for(part=isect)
//        if(len(part)==1)
//          move(part[0]) sphere(r=1);
//        else
//          stroke(part);
// Example(2D): Here the line is treated as a ray. 
//   hex = hexagon(r=15);
//   line = [[0,0],[25,-7]];
//   isect = polygon_line_intersection(hex,line,RAY);
//   stroke(hex,closed=true);
//   stroke(line,endcap2="arrow2");
//   color("red")
//     for(part=isect)
//        if(len(part)==1)
//          move(part[0]) circle(r=1,$fn=12);
//        else
//          stroke(part);
// Example(2D): Here the intersection is a single point, which is returned as a single point "path" on the path list.
//   hex = hexagon(r=15);
//   line = [[15,-10],[15,13]];
//   isect = polygon_line_intersection(hex,line,RAY);
//   stroke(hex,closed=true);
//   stroke(line,endcap2="arrow2");
//   color("red")
//     for(part=isect)
//        if(len(part)==1)
//          move(part[0]) circle(r=1,$fn=12);
//        else
//          stroke(part);
// Example(2D): Another way to get a single segment
//   hex = hexagon(r=15);
//   line = rot(30,p=[[15,-10],[15,25]],cp=[15,0]);
//   isect = polygon_line_intersection(hex,line,RAY);
//   stroke(hex,closed=true);
//   stroke(line,endcap2="arrow2");
//   color("red")
//     for(part=isect)
//        if(len(part)==1)
//          move(part[0]) circle(r=1,$fn=12);
//        else
//          stroke(part);
// Example(2D): Single segment again
//   star = star(r=15,n=8,step=2);
//   line = [[20,-5],[-5,20]];
//   isect = polygon_line_intersection(star,line,RAY);
//   stroke(star,closed=true);
//   stroke(line,endcap2="arrow2");
//   color("red")
//     for(part=isect)
//        if(len(part)==1)
//          move(part[0]) circle(r=1,$fn=12);
//        else
//          stroke(part);
// Example(2D): Solution is two points
//   star = star(r=15,n=8,step=3);
//   line = rot(22.5,p=[[15,-10],[15,20]],cp=[15,0]);
//   isect = polygon_line_intersection(star,line,SEGMENT);
//   stroke(star,closed=true);
//   stroke(line);
//   color("red")
//     for(part=isect)
//        if(len(part)==1)
//          move(part[0]) circle(r=1,$fn=12);
//        else
//          stroke(part);
// Example(2D): Solution is list of three segments
//   star = star(r=25,ir=9,n=8);
//   line = [[-25,12],[25,12]];
//   isect = polygon_line_intersection(star,line);
//   stroke(star,closed=true);
//   stroke(line,endcaps="arrow2");
//   color("red")
//     for(part=isect)
//        if(len(part)==1)
//          move(part[0]) circle(r=1,$fn=12);
//        else
//          stroke(part);
// Example(2D): Solution is a mixture of segments and points
//   star = star(r=25,ir=9,n=7);
//   line = [left(10,p=star[8]), right(50,p=star[8])];
//   isect = polygon_line_intersection(star,line);
//   stroke(star,closed=true);
//   stroke(line,endcaps="arrow2");
//   color("red")
//     for(part=isect)
//        if(len(part)==1)
//          move(part[0]) circle(r=1,$fn=12);
//        else
//          stroke(part);
function polygon_line_intersection(poly, line, bounded=false, nonzero=false, eps=EPSILON) =
    assert( is_finite(eps) && eps>=0, "The tolerance should be a positive number." )
    assert(is_path(poly,dim=[2,3]), "Invalid polygon." )
    assert(is_bool(bounded) || is_bool_list(bounded,2), "Invalid bound condition.")
    assert(_valid_line(line,dim=len(poly[0]),eps=eps), "Line invalid or does not match polygon dimension." )
    let(
        bounded = force_list(bounded,2),
        poly = deduplicate(poly)
    )
    len(poly[0])==2 ?  // planar case
       let( 
            linevec = unit(line[1] - line[0]),
            bound = 100*max(v_abs(flatten(pointlist_bounds(poly)))),
            boundedline = [line[0] + (bounded[0]? 0 : -bound) * linevec,
                           line[1] + (bounded[1]? 0 :  bound) * linevec],
            parts = split_region_at_region_crossings(boundedline, [poly], closed1=false)[0][0],
            inside = [
                      if(point_in_polygon(parts[0][0], poly, nonzero=nonzero, eps=eps) == 0)
                         [parts[0][0]],   // Add starting point if it is on the polygon
                      for(part = parts)
                         if (point_in_polygon(mean(part), poly, nonzero=nonzero, eps=eps) >=0 )
                             part
                         else if(len(part)==2 && point_in_polygon(part[1], poly, nonzero=nonzero, eps=eps) == 0)
                             [part[1]]   // Add segment end if it is on the polygon
                     ]
        )
        (len(inside)==0 ? undef : _merge_segments(inside, [inside[0]], eps))
    : // 3d case
       let(indices = noncollinear_triple(poly))
       indices==[] ? undef :   // Polygon is collinear
       let(
           plane = plane3pt(poly[indices[0]], poly[indices[1]], poly[indices[2]]),
           plane_isect = plane_line_intersection(plane, line, bounded, eps)
       )
       is_undef(plane_isect) ? undef :  
       is_vector(plane_isect,3) ?  
           let(
               poly2d = project_plane(plane,poly),
               pt2d = project_plane(plane, plane_isect)
           )
           (point_in_polygon(pt2d, poly2d, nonzero=nonzero, eps=eps) < 0 ? undef : plane_isect)
       : // Case where line is on the polygon plane
           let(
               poly2d = project_plane(plane, poly),
               line2d = project_plane(plane, line),
               segments = polygon_line_intersection(poly2d, line2d, bounded=bounded, nonzero=nonzero, eps=eps)
           )
           segments==undef ? undef
         : [for(seg=segments) len(seg)==2 ? lift_plane(plane,seg) : [lift_plane(plane,seg[0])]];

function _merge_segments(insegs,outsegs, eps, i=1) = 
    i==len(insegs) ? outsegs : 
    approx(last(last(outsegs)), insegs[i][0], eps) 
        ? _merge_segments(insegs, [each list_head(outsegs),[last(outsegs)[0],last(insegs[i])]], eps, i+1)
        : _merge_segments(insegs, [each outsegs, insegs[i]], eps, i+1);


// Function: plane_intersection()
// Usage:
//   line = plane_intersection(plane1, plane2)
//   pt = plane_intersection(plane1, plane2, plane3)
// Topics: Geometry, Planes, Intersection
// Description:
//   Compute the point which is the intersection of the three planes, or the line intersection of two planes.
//   If you give three planes the intersection is returned as a point.  If you give two planes the intersection
//   is returned as a list of two points on the line of intersection.  If any two input planes are parallel
//   or coincident then returns undef.
// Arguments:
//   plane1 = The [A,B,C,D] coefficients for the first plane equation `Ax+By+Cz=D`.
//   plane2 = The [A,B,C,D] coefficients for the second plane equation `Ax+By+Cz=D`.
//   plane3 = The [A,B,C,D] coefficients for the third plane equation `Ax+By+Cz=D`.
function plane_intersection(plane1,plane2,plane3) =
    assert( _valid_plane(plane1) && _valid_plane(plane2) && (is_undef(plane3) ||_valid_plane(plane3)),
                "The input must be 2 or 3 planes." )
    is_def(plane3)
      ? let(
            matrix = [for(p=[plane1,plane2,plane3]) point3d(p)],
            rhs = [for(p=[plane1,plane2,plane3]) p[3]]
        )
        linear_solve(matrix,rhs)
      : let( normal = cross(plane_normal(plane1), plane_normal(plane2)) )
        approx(norm(normal),0) ? undef :
        let(
            matrix = [for(p=[plane1,plane2]) point3d(p)],
            rhs = [plane1[3], plane2[3]],
            point = linear_solve(matrix,rhs)
        )
        point==[]? undef:
        [point, point+normal];



// Function: plane_line_angle()
// Usage:
//   angle = plane_line_angle(plane,line);
// Topics: Geometry, Planes, Lines, Angle
// Description:
//   Compute the angle between a plane [A, B, C, D] and a 3d line, specified as a pair of 3d points [p1,p2].
//   The resulting angle is signed, with the sign positive if the vector p2-p1 lies above the plane, on
//   the same side of the plane as the plane's normal vector.
function plane_line_angle(plane, line) =
    assert( _valid_plane(plane), "Invalid plane." )
    assert( _valid_line(line,dim=3), "Invalid 3d line." )
    let(
        linedir   = unit(line[1]-line[0]),
        normal    = plane_normal(plane),
        sin_angle = linedir*normal,
        cos_angle = norm(cross(linedir,normal))
    ) atan2(sin_angle,cos_angle);



// Function: plane_closest_point()
// Usage:
//   pts = plane_closest_point(plane, points);
// Topics: Geometry, Planes, Projection
// Description:
//   Given a plane definition `[A,B,C,D]`, where `Ax+By+Cz=D`, and a list of 2d or
//   3d points, return the closest 3D orthogonal projection of the points on the plane.
//   In other words, for every point given, returns the closest point to it on the plane.
// Arguments:
//   plane = The `[A,B,C,D]` plane definition where `Ax+By+Cz=D` is the formula of the plane.
//   points = List of points to project
// Example(FlatSpin,VPD=500,VPT=[2,20,10]):
//   points = move([10,20,30], p=yrot(25, p=path3d(circle(d=100, $fn=36))));
//   plane = plane_from_normal([1,0,1]);
//   proj = plane_closest_point(plane,points);
//   color("red") move_copies(points) sphere(d=4,$fn=12);
//   color("blue") move_copies(proj) sphere(d=4,$fn=12);
//   move(centroid(proj)) {
//       rot(from=UP,to=plane_normal(plane)) {
//           anchor_arrow(50);
//           %cube([120,150,0.1],center=true);
//       }
//   }
function plane_closest_point(plane, points) =
    is_vector(points,3) ? plane_closest_point(plane,[points])[0] :
    assert( _valid_plane(plane), "Invalid plane." )
    assert( is_matrix(points,undef,3), "Must supply 3D points.")
    let(
        plane = _normalize_plane(plane),
        n = point3d(plane)
    )
    [for(pi=points) pi - (pi*n - plane[3])*n];


// Function: point_plane_distance()
// Usage:
//   dist = point_plane_distance(plane, point)
// Topics: Geometry, Planes, Distance
// Description:
//   Given a plane as [A,B,C,D] where the cartesian equation for that plane
//   is Ax+By+Cz=D, determines how far from that plane the given point is.
//   The returned distance will be positive if the point is above the
//   plane, meaning on the side where the plane normal points.  
//   If the point is below the plane, then the distance returned
//   will be negative.  The normal of the plane is [A,B,C].
// Arguments:
//   plane = The `[A,B,C,D]` plane definition where `Ax+By+Cz=D` is the formula of the plane.
//   point = The distance evaluation point.
function point_plane_distance(plane, point) =
    assert( _valid_plane(plane), "Invalid input plane." )
    assert( is_vector(point,3), "The point should be a 3D point." )
    let( plane = _normalize_plane(plane) )
    point3d(plane)* point - plane[3];



// the maximum distance from points to the plane
function _pointlist_greatest_distance(points,plane) =
    let(
        normal = [plane[0],plane[1],plane[2]],
        pt_nrm = points*normal
    )
    max( max(pt_nrm) - plane[3], -min(pt_nrm) + plane[3]) / norm(normal);


// Function: are_points_on_plane()
// Usage:
//   test = are_points_on_plane(points, plane, [eps]);
// Topics: Geometry, Planes, Points
// Description:
//   Returns true if the given 3D points are on the given plane.
// Arguments:
//   plane = The plane to test the points on.
//   points = The list of 3D points to test.
//   eps = Tolerance in geometric comparisons.  Default: `EPSILON` (1e-9)
function are_points_on_plane(points, plane, eps=EPSILON) =
    assert( _valid_plane(plane), "Invalid plane." )
    assert( is_matrix(points,undef,3) && len(points)>0, "Invalid pointlist." ) // using is_matrix it accepts len(points)==1
    assert( is_finite(eps) && eps>=0, "The tolerance should be a positive number." )
    _pointlist_greatest_distance(points,plane) < eps;


/// Internal Function: is_point_above_plane()
/// Usage:
///   test = _is_point_above_plane(plane, point);
/// Topics: Geometry, Planes
// Description:
///   Given a plane as [A,B,C,D] where the cartesian equation for that plane
///   is Ax+By+Cz=D, determines if the given 3D point is on the side of that
///   plane that the normal points towards.  The normal of the plane is the
///   same as [A,B,C].
/// Arguments:
///   plane = The [A,B,C,D] coefficients for the first plane equation `Ax+By+Cz=D`.
///   point = The 3D point to test.
function _is_point_above_plane(plane, point) =
    point_plane_distance(plane, point) > EPSILON;



// Section: Circle Calculations

// Function: circle_line_intersection()
// Usage:
//   isect = circle_line_intersection(c,<r|d>,[line],[bounded],[eps]);
// Topics: Geometry, Circles, Lines, Intersection
// Description:
//   Find intersection points between a 2d circle and a line, ray or segment specified by two points.
//   By default the line is unbounded.
// Arguments:
//   c = center of circle
//   r = radius of circle
//   ---
//   d = diameter of circle
//   line = two points defining the unbounded line
//   bounded = false for unbounded line, true for a segment, or a vector [false,true] or [true,false] to specify a ray with the first or second end unbounded.  Default: false
//   eps = epsilon used for identifying the case with one solution.  Default: 1e-9
function circle_line_intersection(c,r,d,line,bounded=false,eps=EPSILON) =
  let(r=get_radius(r=r,d=d,dflt=undef))
  assert(_valid_line(line,2), "Invalid 2d line.")
  assert(is_vector(c,2), "Circle center must be a 2-vector")
  assert(is_num(r) && r>0, "Radius must be positive")
  assert(is_bool(bounded) || is_bool_list(bounded,2), "Invalid bound condition")
  let(
      bounded = force_list(bounded,2),
      closest = line_closest_point(line,c),
      d = norm(closest-c)
  )
  d > r ? [] :
  let(
     isect = approx(d,r,eps) ? [closest] :
             let( offset = sqrt(r*r-d*d),
                  uvec=unit(line[1]-line[0])
             ) [closest-offset*uvec, closest+offset*uvec]
  )
  [for(p=isect)
     if ((!bounded[0] || (p-line[0])*(line[1]-line[0])>=0)
        && (!bounded[1] || (p-line[1])*(line[0]-line[1])>=0)) p];


// Function&Module: circle_2tangents()
// Usage: As Function
//   circ = circle_2tangents(pt1, pt2, pt3, r|d, [tangents]);
// Topics: Geometry, Circles, Tangents
// Usage: As Module
//   circle_2tangents(pt1, pt2, pt3, r|d, [h], [center]);
// Description:
//   Given a pair of rays with a common origin, and a known circle radius/diameter, finds
//   the centerpoint for the circle of that size that touches both rays tangentally.
//   Both rays start at `pt2`, one passing through `pt1`, and the other through `pt3`.
//   .
//   When called as a module with an `h` height argument, creates a 3D cylinder of `h`
//   length at the found centerpoint, aligned with the found normal.
//   .
//   When called as a module with 2D data and no `h` argument, creates a 2D circle of
//   the given radius/diameter, tangentially touching both rays.
//   .
//   When called as a function with collinear rays, returns `undef`.
//   Otherwise, when called as a function with `tangents=false`, returns `[CP,NORMAL]`.
//   Otherwise, when called as a function with `tangents=true`, returns `[CP,NORMAL,TANPT1,TANPT2,ANG1,ANG2]`.
//   - CP is the centerpoint of the circle.
//   - NORMAL is the normal vector of the plane that the circle is on (UP or DOWN if the points are 2D).
//   - TANPT1 is the point where the circle is tangent to the ray `[pt2,pt1]`.
//   - TANPT2 is the point where the circle is tangent to the ray `[pt2,pt3]`.
//   - ANG1 is the angle from the ray `[CP,pt2]` to the ray `[CP,TANPT1]`
//   - ANG2 is the angle from the ray `[CP,pt2]` to the ray `[CP,TANPT2]`
// Arguments:
//   pt1 = A point that the first ray passes though.
//   pt2 = The starting point of both rays.
//   pt3 = A point that the second ray passes though.
//   r = The radius of the circle to find.
//   d = The diameter of the circle to find.
//   h = Height of the cylinder to create, when called as a module.
//   center = When called as a module, center the cylinder if true,  Default: false
//   tangents = If true, extended information about the tangent points is calculated and returned.  Default: false
// Example(2D):
//   pts = [[60,40], [10,10], [65,5]];
//   rad = 10;
//   stroke([pts[1],pts[0]], endcap2="arrow2");
//   stroke([pts[1],pts[2]], endcap2="arrow2");
//   circ = circle_2tangents(pt1=pts[0], pt2=pts[1], pt3=pts[2], r=rad);
//   translate(circ[0]) {
//       color("green") {
//           stroke(circle(r=rad),closed=true);
//           stroke([[0,0],rad*[cos(315),sin(315)]]);
//       }
//   }
//   move_copies(pts) color("blue") circle(d=2, $fn=12);
//   translate(circ[0]) color("red") circle(d=2, $fn=12);
//   labels = [[pts[0], "pt1"], [pts[1],"pt2"], [pts[2],"pt3"], [circ[0], "CP"], [circ[0]+[cos(315),sin(315)]*rad*0.7, "r"]];
//   for(l=labels) translate(l[0]+[0,2]) color("black") text(text=l[1], size=2.5, halign="center");
// Example(2D):
//   pts = [[-5,25], [5,-25], [45,15]];
//   rad = 12;
//   color("blue") stroke(pts, width=0.75, endcaps="arrow2");
//   circle_2tangents(pt1=pts[0], pt2=pts[1], pt3=pts[2], r=rad);
// Example: Non-centered Cylinder
//   pts = [[45,15,10], [5,-25,5], [-5,25,20]];
//   rad = 12;
//   color("blue") stroke(pts, width=0.75, endcaps="arrow2");
//   circle_2tangents(pt1=pts[0], pt2=pts[1], pt3=pts[2], r=rad, h=10, center=false);
// Example: Non-centered Cylinder
//   pts = [[45,15,10], [5,-25,5], [-5,25,20]];
//   rad = 12;
//   color("blue") stroke(pts, width=0.75, endcaps="arrow2");
//   circle_2tangents(pt1=pts[0], pt2=pts[1], pt3=pts[2], r=rad, h=10, center=true);
function circle_2tangents(pt1, pt2, pt3, r, d, tangents=false) =
    let(r = get_radius(r=r, d=d, dflt=undef))
    assert(r!=undef, "Must specify either r or d.")
    assert( ( is_path(pt1) && len(pt1)==3 && is_undef(pt2) && is_undef(pt3))
            || (is_matrix([pt1,pt2,pt3]) && (len(pt1)==2 || len(pt1)==3) ),
            "Invalid input points." )
    is_undef(pt2)
    ? circle_2tangents(pt1[0], pt1[1], pt1[2], r=r, tangents=tangents)
    : is_collinear(pt1, pt2, pt3)? undef :
        let(
            v1 = unit(pt1 - pt2),
            v2 = unit(pt3 - pt2),
            vmid = unit(mean([v1, v2])),
            n = vector_axis(v1, v2),
            a = vector_angle(v1, v2),
            hyp = r / sin(a/2),
            cp = pt2 + hyp * vmid
        )
        !tangents ? [cp, n] :
        let(
            x = hyp * cos(a/2),
            tp1 = pt2 + x * v1,
            tp2 = pt2 + x * v2,
            dang1 = vector_angle(tp1-cp,pt2-cp),
            dang2 = vector_angle(tp2-cp,pt2-cp)
        )
        [cp, n, tp1, tp2, dang1, dang2];


module circle_2tangents(pt1, pt2, pt3, r, d, h, center=false) {
    c = circle_2tangents(pt1=pt1, pt2=pt2, pt3=pt3, r=r, d=d);
    assert(!is_undef(c), "Cannot find circle when both rays are collinear.");
    cp = c[0]; n = c[1];
    if (approx(point3d(cp).z,0) && approx(point2d(n),[0,0]) && is_undef(h)) {
        translate(cp) circle(r=r, d=d);
    } else {
        assert(is_finite(h), "h argument required when result is not flat on the XY plane.");
        translate(cp) {
            rot(from=UP, to=n) {
                cylinder(r=r, d=d, h=h, center=center);
            }
        }
    }
}


// Function&Module: circle_3points()
// Usage: As Function
//   circ = circle_3points(pt1, pt2, pt3);
//   circ = circle_3points([pt1, pt2, pt3]);
// Topics: Geometry, Circles
// Usage: As Module
//   circle_3points(pt1, pt2, pt3, [h], [center]);
//   circle_3points([pt1, pt2, pt3], [h], [center]);
// Description:
//   Returns the [CENTERPOINT, RADIUS, NORMAL] of the circle that passes through three non-collinear
//   points where NORMAL is the normal vector of the plane that the circle is on (UP or DOWN if the points are 2D).
//   The centerpoint will be a 2D or 3D vector, depending on the points input.  If all three
//   points are 2D, then the resulting centerpoint will be 2D, and the normal will be UP ([0,0,1]).
//   If any of the points are 3D, then the resulting centerpoint will be 3D.  If the three points are
//   collinear, then `[undef,undef,undef]` will be returned.  The normal will be a normalized 3D
//   vector with a non-negative Z axis.
//   Instead of 3 arguments, it is acceptable to input the 3 points in a list `pt1`, leaving `pt2`and `pt3` as undef.
// Arguments:
//   pt1 = The first point.
//   pt2 = The second point.
//   pt3 = The third point.
//   h = Height of the cylinder to create, when called as a module.
//   center = When called as a module, center the cylinder if true,  Default: false
// Example(2D):
//   pts = [[60,40], [10,10], [65,5]];
//   circ = circle_3points(pts[0], pts[1], pts[2]);
//   translate(circ[0]) color("green") stroke(circle(r=circ[1]),closed=true,$fn=72);
//   translate(circ[0]) color("red") circle(d=3, $fn=12);
//   move_copies(pts) color("blue") circle(d=3, $fn=12);
// Example(2D):
//   pts = [[30,40], [10,20], [55,30]];
//   circle_3points(pts[0], pts[1], pts[2]);
//   move_copies(pts) color("blue") circle(d=3, $fn=12);
// Example: Non-Centered Cylinder
//   pts = [[30,15,30], [10,20,15], [55,25,25]];
//   circle_3points(pts[0], pts[1], pts[2], h=10, center=false);
//   move_copies(pts) color("cyan") sphere(d=3, $fn=12);
// Example: Centered Cylinder
//   pts = [[30,15,30], [10,20,15], [55,25,25]];
//   circle_3points(pts[0], pts[1], pts[2], h=10, center=true);
//   move_copies(pts) color("cyan") sphere(d=3, $fn=12);
function circle_3points(pt1, pt2, pt3) =
    (is_undef(pt2) && is_undef(pt3) && is_list(pt1))
      ? circle_3points(pt1[0], pt1[1], pt1[2])
      : assert( is_vector(pt1) && is_vector(pt2) && is_vector(pt3)
                && max(len(pt1),len(pt2),len(pt3))<=3 && min(len(pt1),len(pt2),len(pt3))>=2,
                "Invalid point(s)." )
        is_collinear(pt1,pt2,pt3)? [undef,undef,undef] :
        let(
            v  = [ point3d(pt1), point3d(pt2), point3d(pt3) ], // triangle vertices
            ed = [for(i=[0:2]) v[(i+1)%3]-v[i] ],    // triangle edge vectors
            pm = [for(i=[0:2]) v[(i+1)%3]+v[i] ]/2,  // edge mean points
            es = sortidx( [for(di=ed) norm(di) ] ),
            e1 = ed[es[1]],                          // take the 2 longest edges
            e2 = ed[es[2]],
            n0 = vector_axis(e1,e2),                 // normal standardization
            n  = n0.z<0? -n0 : n0,
            sc = plane_intersection(
                    [ each e1, e1*pm[es[1]] ],       // planes orthogonal to 2 edges
                    [ each e2, e2*pm[es[2]] ],
                    [ each n,  n*v[0] ]
                ),  // triangle plane
            cp = len(pt1)+len(pt2)+len(pt3)>6 ? sc : [sc.x, sc.y],
            r  = norm(sc-v[0])
        ) [ cp, r, n ];


module circle_3points(pt1, pt2, pt3, h, center=false) {
    c = circle_3points(pt1, pt2, pt3);
    assert(!is_undef(c[0]), "Points cannot be collinear.");
    cp = c[0];  r = c[1];  n = c[2];
    if (approx(point3d(cp).z,0) && approx(point2d(n),[0,0]) && is_undef(h)) {
        translate(cp) circle(r=r);
    } else {
        assert(is_finite(h));
        translate(cp) rot(from=UP,to=n) cylinder(r=r, h=h, center=center);
    }
}


// Function: circle_point_tangents()
// Usage:
//   tangents = circle_point_tangents(r|d, cp, pt);
// Topics: Geometry, Circles, Tangents
// Description:
//   Given a 2d circle and a 2d point outside that circle, finds the 2d tangent point(s) on the circle for a
//   line passing through the point.  Returns a list of zero or more 2D tangent points.
// Arguments:
//   r = Radius of the circle.
//   d = Diameter of the circle.
//   cp = The coordinates of the 2d circle centerpoint.
//   pt = The coordinates of the 2d external point.
// Example(3D):
//   cp = [-10,-10];  r = 30;  pt = [30,10];
//   tanpts = circle_point_tangents(r=r, cp=cp, pt=pt);
//   color("yellow") translate(cp) circle(r=r);
//   color("cyan") for(tp=tanpts) {stroke([tp,pt]); stroke([tp,cp]);}
//   color("red") move_copies(tanpts) circle(d=3,$fn=12);
//   color("blue") move_copies([cp,pt]) circle(d=3,$fn=12);
function circle_point_tangents(r, d, cp, pt) =
    assert(is_finite(r) || is_finite(d), "Invalid radius or diameter." )
    assert(is_path([cp, pt],dim=2), "Invalid center point or external point.")
    let(
        r = get_radius(r=r, d=d, dflt=1),
        delta = pt - cp,
        dist = norm(delta),
        baseang = atan2(delta.y,delta.x)
    ) dist < r? [] :
    approx(dist,r)? [pt] :
    let(
        relang = acos(r/dist),
        angs = [baseang + relang, baseang - relang]
    ) [for (ang=angs) cp + r*[cos(ang),sin(ang)]];


// Function: circle_circle_tangents()
// Usage:
//   segs = circle_circle_tangents(c1, r1|d1, c2, r2|d2);
// Topics: Geometry, Circles, Tangents
// Description:
//   Computes 2d lines tangents to a pair of circles in 2d.  Returns a list of line endpoints [p1,p2] where
//   p2 is the tangent point on circle 1 and p2 is the tangent point on circle 2.
//   If four tangents exist then the first one the left hand exterior tangent as regarded looking from
//   circle 1 toward circle 2.  The second value is the right hand exterior tangent.  The third entry
//   gives the interior tangent that starts on the left of circle 1 and crosses to the right side of
//   circle 2.  And the fourth entry is the last interior tangent that starts on the right side of
//   circle 1.  If the circles intersect then the interior tangents don't exist and the function
//   returns only two entries.  If one circle is inside the other one then no tangents exist
//   so the function returns the empty set.  When the circles are tangent a degenerate tangent line
//   passes through the point of tangency of the two circles:  this degenerate line is NOT returned.
// Arguments:
//   c1 = Center of the first circle.
//   r1 = Radius of the first circle.
//   c2 = Center of the second circle.
//   r2 = Radius of the second circle.
//   d1 = Diameter of the first circle.
//   d2 = Diameter of the second circle.
// Example(2D,NoAxes): Four tangents, first in green, second in black, third in blue, last in red.
//   $fn=32;
//   c1 = [3,4];  r1 = 2;
//   c2 = [7,10]; r2 = 3;
//   pts = circle_circle_tangents(c1,r1,c2,r2);
//   move(c1) stroke(circle(r=r1), width=0.2, closed=true);
//   move(c2) stroke(circle(r=r2), width=0.2, closed=true);
//   colors = ["green","black","blue","red"];
//   for(i=[0:len(pts)-1]) color(colors[i]) stroke(pts[i],width=0.2);
// Example(2D,NoAxes): Circles overlap so only exterior tangents exist.
//   $fn=32;
//   c1 = [4,4];  r1 = 3;
//   c2 = [7,7]; r2 = 2;
//   pts = circle_circle_tangents(c1,r1,c2,r2);
//   move(c1) stroke(circle(r=r1), width=0.2, closed=true);
//   move(c2) stroke(circle(r=r2), width=0.2, closed=true);
//   colors = ["green","black","blue","red"];
//   for(i=[0:len(pts)-1]) color(colors[i]) stroke(pts[i],width=0.2);
// Example(2D,NoAxes): Circles are tangent.  Only exterior tangents are returned.  The degenerate internal tangent is not returned.
//   $fn=32;
//   c1 = [4,4];  r1 = 4;
//   c2 = [4,10]; r2 = 2;
//   pts = circle_circle_tangents(c1,r1,c2,r2);
//   move(c1) stroke(circle(r=r1), width=0.2, closed=true);
//   move(c2) stroke(circle(r=r2), width=0.2, closed=true);
//   colors = ["green","black","blue","red"];
//   for(i=[0:1:len(pts)-1]) color(colors[i]) stroke(pts[i],width=0.2);
// Example(2D,NoAxes): One circle is inside the other: no tangents exist.  If the interior circle is tangent the single degenerate tangent will not be returned.
//   $fn=32;
//   c1 = [4,4];  r1 = 4;
//   c2 = [5,5];  r2 = 2;
//   pts = circle_circle_tangents(c1,r1,c2,r2);
//   move(c1) stroke(circle(r=r1), width=0.2, closed=true);
//   move(c2) stroke(circle(r=r2), width=0.2, closed=true);
//   echo(pts);   // Returns []
function circle_circle_tangents(c1,r1,c2,r2,d1,d2) =
    assert( is_path([c1,c2],dim=2), "Invalid center point(s)." )
    let(
        r1 = get_radius(r1=r1,d1=d1),
        r2 = get_radius(r1=r2,d1=d2),
        Rvals = [r2-r1, r2-r1, -r2-r1, -r2-r1]/norm(c1-c2),
        kvals = [-1,1,-1,1],
        ext = [1,1,-1,-1],
        N = 1-sqr(Rvals[2])>=0 ? 4 :
            1-sqr(Rvals[0])>=0 ? 2 : 0,
        coef= [
            for(i=[0:1:N-1]) [
                [Rvals[i], -kvals[i]*sqrt(1-sqr(Rvals[i]))],
                [kvals[i]*sqrt(1-sqr(Rvals[i])), Rvals[i]]
            ] * unit(c2-c1)
        ]
    ) [
        for(i=[0:1:N-1]) let(
            pt = [
                c1-r1*coef[i],
                c2-ext[i]*r2*coef[i]
            ]
        ) if (pt[0]!=pt[1]) pt
    ];



// Section: Pointlists


// Function: noncollinear_triple()
// Usage:
//   test = noncollinear_triple(points);
// Topics: Geometry, Noncollinearity
// Description:
//   Finds the indices of three non-collinear points from the pointlist `points`.
//   It selects two well separated points to define a line and chooses the third point
//   to be the point farthest off the line.  The points do not necessarily having the
//   same winding direction as the polygon so they cannot be used to determine the
//   winding direction or the direction of the normal.  
//   If all points are collinear returns [] when `error=true` or an error otherwise .
// Arguments:
//   points = List of input points.
//   error = Defines the behaviour for collinear input points. When `true`, produces an error, otherwise returns []. Default: `true`.
//   eps = Tolerance for collinearity test. Default: EPSILON.
function noncollinear_triple(points,error=true,eps=EPSILON) =
    assert( is_path(points), "Invalid input points." )
    assert( is_finite(eps) && (eps>=0), "The tolerance should be a non-negative value." )
    len(points)<3 ? [] :
    let(
        pa = points[0],
        b  = furthest_point(pa, points),
        pb = points[b],
        nrm = norm(pa-pb)
    )
    nrm <= eps ?
        assert(!error, "Cannot find three noncollinear points in pointlist.") [] :
    let(
        n = (pb-pa)/nrm,
        distlist = [for(i=[0:len(points)-1]) _dist2line(points[i]-pa, n)]
    )
    max(distlist) < eps*nrm ?
        assert(!error, "Cannot find three noncollinear points in pointlist.") [] :
    [0, b, max_index(distlist)];



// Section: Polygons

// Function: polygon_area()
// Usage:
//   area = polygon_area(poly);
// Topics: Geometry, Polygons, Area
// Description:
//   Given a 2D or 3D simple planar polygon, returns the area of that polygon.
//   If the polygon is non-planar the result is `undef.`  If the polygon is self-intersecting
//   then the return will be a meaningless number.  
//   When `signed` is true and the polygon is 2d, a signed area is returned: a positive area indicates a counter-clockwise polygon.
//   The area of 3d polygons is always nonnegative.  
// Arguments:
//   poly = Polygon to compute the area of.
//   signed = If true, a signed area is returned. Default: false.
function polygon_area(poly, signed=false) =
    assert(is_path(poly), "Invalid polygon." )
    len(poly)<3 ? 0 :
    len(poly[0])==2
      ? let( total = sum([for(i=[1:1:len(poly)-2]) cross(poly[i]-poly[0],poly[i+1]-poly[0]) ])/2 )
        signed ? total : abs(total)
      : let( plane = plane_from_polygon(poly) )
        is_undef(plane) ? undef :
        let( 
            n = plane_normal(plane),  
            total = 
                -sum([ for(i=[1:1:len(poly)-2])
                        cross(poly[i]-poly[0], poly[i+1]-poly[0]) 
                    ]) * n/2
        ) 
        signed ? total : abs(total);


// Function: centroid()
// Usage:
//   c = centroid(object, [eps]);
// Topics: Geometry, Polygons, Centroid
// Description:
//   Given a simple 2D polygon, returns the 2D coordinates of the polygon's centroid.
//   Given a simple 3D planar polygon, returns the 3D coordinates of the polygon's centroid.
//   If you provide a non-planar or collinear polygon you will get an error.  For self-intersecting
//   polygons you may get an error or you may get meaningless results.
//   .
//   If object is a manifold VNF then returns the 3d centroid of the polyhedron.  The VNF must
//   describe a valid polyhedron with consistent face direction and no holes in the mesh; otherwise
//   the results are undefined.
// Arguments:
//   object = object to compute the centroid of
//   eps = epsilon value for identifying degenerate cases
function centroid(object,eps=EPSILON) =
    assert(is_finite(eps) && (eps>=0), "The tolerance should a non-negative value." )
    is_vnf(object) ? _vnf_centroid(object,eps)
  : is_path(object,[2,3]) ? _polygon_centroid(object,eps)
  : is_region(object) ? (len(object)==1 ? _polygon_centroid(object[0],eps) : _region_centroid(object,eps))
  : assert(false, "Input must be a VNF, a region, or a 2D or 3D polygon");


/// Internal Function: _region_centroid()
/// Compute centroid of region
function _region_centroid(region,eps=EPSILON) =
   let(
       region=force_region(region),
       parts = region_parts(region),
       // Rely on region_parts returning all outside polygons clockwise
       // and inside (hole) polygons counterclockwise, so areas have reversed sign
       cent_area = [for(R=parts, p=R)
                       let(A=polygon_area(p,signed=true))
                       [A*_polygon_centroid(p),A]],
       total = sum(cent_area)
   )
   total[0]/total[1];


/// Function: _polygon_centroid()
/// Usage:
///   cpt = _polygon_centroid(poly);
/// Topics: Geometry, Polygons, Centroid
/// Description:
///   Given a simple 2D polygon, returns the 2D coordinates of the polygon's centroid.
///   Given a simple 3D planar polygon, returns the 3D coordinates of the polygon's centroid.
///   Collinear points produce an error.  The results are meaningless for self-intersecting
///   polygons or an error is produced.
/// Arguments:
///   poly = Points of the polygon from which the centroid is calculated.
///   eps = Tolerance in geometric comparisons.  Default: `EPSILON` (1e-9)
function _polygon_centroid(poly, eps=EPSILON) =
    assert( is_path(poly,dim=[2,3]), "The input must be a 2D or 3D polygon." )
    let(
        n = len(poly[0])==2 ? 1 :
            let( plane = plane_from_points(poly, fast=false))
            assert(!is_undef(plane), "The polygon must be planar." )
            plane_normal(plane),
        v0 = poly[0] ,
        val = sum([
            for(i=[1:len(poly)-2])
            let(
                v1 = poly[i],
                v2 = poly[i+1],
                area = cross(v2-v0,v1-v0)*n
            ) [ area, (v0+v1+v2)*area ]
        ])
    )
    assert(!approx(val[0],0, eps), "The polygon is self-intersecting or its points are collinear.")
    val[1]/val[0]/3;



// Function: polygon_normal()
// Usage:
//   vec = polygon_normal(poly);
// Topics: Geometry, Polygons
// Description:
//   Given a 3D simple planar polygon, returns a unit normal vector for the polygon.  The vector
//   is oriented so that if the normal points towards the viewer, the polygon winds in the clockwise
//   direction.  If the polygon has zero area, returns `undef`.  If the polygon is self-intersecting
//   the the result is undefined.  It doesn't check for coplanarity.
// Arguments:
//   poly = The list of 3D path points for the perimeter of the polygon.
function polygon_normal(poly) =
    assert(is_path(poly,dim=3), "Invalid 3D polygon." )
    let(
        area_vec = sum([for(i=[1:len(poly)-2])
                           cross(poly[i]-poly[0],
                                 poly[i+1]-poly[i])])
    )
    unit(-area_vec, error=undef);


// Function: point_in_polygon()
// Usage:
//   test = point_in_polygon(point, poly, [nonzero], [eps])
// Topics: Geometry, Polygons
// Description:
//   This function tests whether the given 2D point is inside, outside or on the boundary of
//   the specified 2D polygon.  
//   The polygon is given as a list of 2D points, not including the repeated end point.
//   Returns -1 if the point is outside the polygon.
//   Returns 0 if the point is on the boundary.
//   Returns 1 if the point lies in the interior.
//   The polygon does not need to be simple: it may have self-intersections.
//   But the polygon cannot have holes (it must be simply connected).
//   Rounding errors may give mixed results for points on or near the boundary.
//   .
//   When polygons intersect themselves different definitions exist for determining which points
//   are inside the polygon.  The figure below shows the difference.
//   OpenSCAD uses the Even-Odd rule when creating polygons, where membership in overlapping regions
//   depends on how many times they overlap.  The Nonzero rule considers point inside the polygon if
//   the polygon overlaps them any number of times.  For more information see
//   https://en.wikipedia.org/wiki/Nonzero-rule and https://en.wikipedia.org/wiki/Even–odd_rule.
// Figure(2D,Med,NoAxes):
//   a=20;
//   b=30;
//   ofs = 17;
//   curve = [for(theta=[0:10:140])  [a * theta/360*2*PI - b*sin(theta), a-b*cos(theta)-20]];
//   path = deduplicate(concat( reverse(offset(curve,r=ofs)),
//                  xflip(offset(curve,r=ofs)),
//                  xflip(reverse(curve)),
//                  curve
//                ));
//   left(40){
//     polygon(path);
//     color("red")stroke(path, width=1, closed=true);
//     color("red")back(28/(2/3))text("Even-Odd", size=5/(2/3), halign="center");
//   }
//   right(40){
//      dp = polygon_parts(path,nonzero=true);
//      region(dp);
//      color("red"){stroke(path,width=1,closed=true);
//                   back(28/(2/3))text("Nonzero", size=5/(2/3), halign="center");
//                   }
//   }  
// Arguments:
//   point = The 2D point to check
//   poly = The list of 2D points forming the perimeter of the polygon.
//   nonzero = The rule to use: true for "Nonzero" rule and false for "Even-Odd". Default: false (Even-Odd)
//   eps = Tolerance in geometric comparisons.  Default: `EPSILON` (1e-9)
// Example(2D): With nonzero set to false (the default), we get this result. Green dots are inside the polygon and red are outside:
//   a=20*2/3;
//   b=30*2/3;
//   ofs = 17*2/3;
//   curve = [for(theta=[0:10:140])  [a * theta/360*2*PI - b*sin(theta), a-b*cos(theta)]];
//   path = deduplicate(concat( reverse(offset(curve,r=ofs)),
//                  xflip(offset(curve,r=ofs)),
//                  xflip(reverse(curve)),
//                  curve
//                ));
//   stroke(path,closed=true);
//   pts = [[0,0],[10,0],[0,20]];
//   for(p=pts){
//     color(point_in_polygon(p,path)==1 ? "green" : "red")
//     move(p)circle(r=1.5, $fn=12);
//   }
// Example(2D): With nonzero set to true, one dot changes color:
//   a=20*2/3;
//   b=30*2/3;
//   ofs = 17*2/3;
//   curve = [for(theta=[0:10:140])  [a * theta/360*2*PI - b*sin(theta), a-b*cos(theta)]];
//   path = deduplicate(concat( reverse(offset(curve,r=ofs)),
//                  xflip(offset(curve,r=ofs)),
//                  xflip(reverse(curve)),
//                  curve
//                ));
//   stroke(path,closed=true);
//   pts = [[0,0],[10,0],[0,20]];
//   for(p=pts){
//     color(point_in_polygon(p,path,nonzero=true)==1 ? "green" : "red")
//     move(p)circle(r=1.5, $fn=12);
//   }

// Internal function for point_in_polygon

function _point_above_below_segment(point, edge) =
    let( edge = edge - [point, point] )
    edge[0].y <= 0
      ? (edge[1].y >  0 && cross(edge[0], edge[1]-edge[0]) > 0) ?  1 : 0
      : (edge[1].y <= 0 && cross(edge[0], edge[1]-edge[0]) < 0) ? -1 : 0;


function point_in_polygon(point, poly, nonzero=false, eps=EPSILON) =
    // Original algorithms from http://geomalgorithms.com/a03-_inclusion.html
    assert( is_vector(point,2) && is_path(poly,dim=2) && len(poly)>2,
            "The point and polygon should be in 2D. The polygon should have more that 2 points." )
    assert( is_finite(eps) && (eps>=0), "The tolerance should be a non-negative value." )
    // Check bounding box
    let(
        box = pointlist_bounds(poly)
    )
    point.x<box[0].x-eps || point.x>box[1].x+eps
        || point.y<box[0].y-eps || point.y>box[1].y+eps  ? -1
    :
    // Does the point lie on any edges?  If so return 0.
    let(
        segs = pair(poly,true),
        on_border = [for (seg=segs)
                       if (norm(seg[0]-seg[1])>eps && _is_point_on_line(point, seg, SEGMENT, eps=eps)) 1]
    )
    on_border != [] ? 0 :
    nonzero    // Compute winding number and return 1 for interior, -1 for exterior
      ? let(
            winding = [
                       for(seg=segs)
                         let(
                             p0=seg[0]-point,
                             p1=seg[1]-point
                         )
                         if (norm(p0-p1)>eps)
                             p0.y <=0
                                ? p1.y > 0 && cross(p0,p1-p0)>0 ? 1 : 0
                                : p1.y <=0 && cross(p0,p1-p0)<0 ? -1: 0
            ]
        )
        sum(winding) != 0 ? 1 : -1
      : // or compute the crossings with the ray [point, point+[1,0]]
        let(
            cross = [
                     for(seg=segs)
                       let(
                           p0 = seg[0]-point,
                           p1 = seg[1]-point
                       )
                       if (
                           ( (p1.y>eps && p0.y<=eps) || (p1.y<=eps && p0.y>eps) )
                           &&  -eps < p0.x - p0.y *(p1.x - p0.x)/(p1.y - p0.y)
                       )
                       1
            ]
        )
        2*(len(cross)%2)-1;




// Function: polygon_triangulate()
// Usage:
//   triangles = polygon_triangulate(poly, [ind], [eps])
// Description:
//   Given a simple polygon in 2D or 3D, triangulates it and returns a list 
//   of triples indexing into the polygon vertices. When the optional argument `ind` is 
//   given, it is used as an index list into `poly` to define the polygon. In that case, 
//   `poly` may have a length greater than `ind`. When `ind` is undefined, all points in `poly` 
//   are considered as vertices of the polygon.
//   .
//   For 2d polygons, the output triangles will have the same winding (CW or CCW) of
//   the input polygon. For 3d polygons, the triangle windings will induce a normal
//   vector with the same direction of the polygon normal.
//   .
//   The function produce correct triangulations for some non-twisted non-simple polygons. 
//   A polygon is non-twisted iff it is simple or there is a partition of it in
//   simple polygons with the same winding. These polygons may have "touching" vertices 
//   (two vertices having the same coordinates, but distinct adjacencies) and "contact" edges 
//   (edges whose vertex pairs have the same pairwise coordinates but are in reversed order) but has 
//   no self-crossing. See examples bellow. If all polygon edges are contact edges, 
//   it returns an empty list for 2d polygons and issues an error for 3d polygons. 
//   .
//   Self-crossing polygons have no consistent winding and usually produce an error but 
//   when an error is not issued the outputs are not correct triangulations. The function
//   can work for 3d non-planar polygons if they are close enough to planar but may otherwise 
//   issue an error for this case. 
// Arguments:
//   poly = Array of vertices for the polygon.
//   ind = A list indexing the vertices of the polygon in `poly`.
//   eps = A maximum tolerance in geometrical tests. Default: EPSILON
// Example(2D,NoAxes):
//   poly = star(id=10, od=15,n=11);
//   tris =  polygon_triangulate(poly);
//   color("lightblue") for(tri=tris) polygon(select(poly,tri));
//   color("blue")    up(1) for(tri=tris) { stroke(select(poly,tri),.15,closed=true); }
//   color("magenta") up(2) stroke(poly,.25,closed=true); 
//   color("black")   up(3) vnf_debug([path3d(poly),[]],faces=false,size=1);
// Example(2D,NoAxes): a polygon with a hole and one "contact" edge
//   poly = [ [-10,0], [10,0], [0,10], [-10,0], [-4,4], [4,4], [0,2], [-4,4] ];
//   tris =  polygon_triangulate(poly);
//   color("lightblue") for(tri=tris) polygon(select(poly,tri));
//   color("blue")    up(1) for(tri=tris) { stroke(select(poly,tri),.15,closed=true); }
//   color("magenta") up(2) stroke(poly,.25,closed=true); 
//   color("black")   up(3) vnf_debug([path3d(poly),[]],faces=false,size=1);
// Example(2D,NoAxes): a polygon with "touching" vertices and no holes
//   poly = [ [0,0], [5,5], [-5,5], [0,0], [-5,-5], [5,-5] ];
//   tris =  polygon_triangulate(poly);
//   color("lightblue") for(tri=tris) polygon(select(poly,tri));
//   color("blue")    up(1) for(tri=tris) { stroke(select(poly,tri),.15,closed=true); }
//   color("magenta") up(2) stroke(poly,.25,closed=true); 
//   color("black")   up(3) vnf_debug([path3d(poly),[]],faces=false,size=1);
// Example(2D,NoAxes): a polygon with "contact" edges and no holes
//   poly = [ [0,0], [10,0], [10,10], [0,10], [0,0], [3,3], [7,3], 
//            [7,7], [7,3], [3,3] ];
//   tris =  polygon_triangulate(poly); // see from the top
//   color("lightblue") for(tri=tris) polygon(select(poly,tri));
//   color("blue")    up(1) for(tri=tris) { stroke(select(poly,tri),.15,closed=true); }
//   color("magenta") up(2) stroke(poly,.25,closed=true); 
//   color("black")   up(3) vnf_debug([path3d(poly),[]],faces=false,size=1);
// Example(3D): 
//   include <BOSL2/polyhedra.scad>
//   vnf = regular_polyhedron_info(name="dodecahedron",side=5,info="vnf");
//   vnf_polyhedron(vnf);
//   vnf_tri = [vnf[0], [for(face=vnf[1]) each polygon_triangulate(vnf[0], face) ] ];
//   color("blue")
//   vnf_wireframe(vnf_tri, width=.15);
function polygon_triangulate(poly, ind, eps=EPSILON) =
    assert(is_path(poly) && len(poly)>=3, "Polygon `poly` should be a list of at least three 2d or 3d points")
    assert(is_undef(ind) 
           || (is_vector(ind) && min(ind)>=0 && max(ind)<len(poly) ),
           "Improper or out of bounds list of indices")
    let( ind = is_undef(ind) ? count(len(poly)) : ind )
    len(ind) == 3 
      ? _is_degenerate([poly[ind[0]], poly[ind[1]], poly[ind[2]]], eps) ? [] :
        // non zero area
        assert( norm(scalar_vec3(cross(poly[ind[1]]-poly[ind[0]], poly[ind[2]]-poly[ind[0]]))) > 2*eps,
                "The polygon vertices are collinear.") 
        [ind]
      : len(poly[ind[0]]) == 3 
          ? // represents the polygon projection on its plane as a 2d polygon 
            let( 
                ind = deduplicate_indexed(poly, ind, eps) 
            )
            len(ind)<3 ? [] :
            let(
                pts = select(poly,ind),
                nrm = polygon_normal(pts)
            )
            assert( nrm!=undef, 
                    "The polygon has self-intersections or its vertices are collinear or non coplanar.") 
            let(
                imax  = max_index([for(p=pts) norm(p-pts[0]) ]),
                v1    = unit( pts[imax] - pts[0] ),
                v2    = cross(v1,nrm),
                prpts = pts*transpose([v1,v2])
            )
            [for(tri=_triangulate(prpts, count(len(ind)), eps)) select(ind,tri) ]
          : let( cw = is_polygon_clockwise(select(poly, ind)) )
            cw 
              ? [for(tri=_triangulate( poly, reverse(ind), eps )) reverse(tri) ]
              : _triangulate( poly, ind, eps );


function _triangulate(poly, ind, eps=EPSILON, tris=[]) =
    len(ind)==3 
    ?   _is_degenerate(select(poly,ind),eps)  
        ?   tris // last 3 pts perform a degenerate triangle, ignore it
        :   concat(tris,[ind]) // otherwise, include it
    :   let( ear = _get_ear(poly,ind,eps) )
        assert( ear!=undef, 
                "The polygon has self-intersections or its vertices are collinear or non coplanar.") 
        is_list(ear) // degenerate ear
        ?   _triangulate(poly, select(ind,ear[0]+2, ear[0]), eps, tris) // discard it
        :   let(
                ear_tri = select(ind,ear,ear+2),
                indr    = select(ind,ear+2, ear) // remaining point indices
            )
            _triangulate(poly, indr, eps, concat(tris,[ear_tri]));


// a returned ear will be:
// 1. a CCW (non-degenerate) triangle, made of subsequent vertices, without other 
//    points inside except possibly at its vertices
// 2. or a degenerate triangle where two vertices are coincident
// the returned ear is specified by the index of `ind` of its first vertex
function _get_ear(poly, ind, eps, _i=0) =
    _i>=len(ind) ? undef : // poly has no ears
    let( // the _i-th ear candidate
        p0 = poly[ind[_i]],
        p1 = poly[ind[(_i+1)%len(ind)]],
        p2 = poly[ind[(_i+2)%len(ind)]]
    )
    // degenerate triangles are returned codified
    _is_degenerate([p0,p1,p2],eps)  ? [_i] : 
    // if it is not a convex vertex, check the next one
    _is_cw2(p0,p1,p2,eps) ? _get_ear(poly,ind,eps, _i=_i+1) : 
    let( // vertex p1 is convex
         // check if the triangle contains any other point
         // except possibly its own vertices
        to_tst = select(ind,_i+3, _i-1),
        q      = [(p0-p2).y, (p2-p0).x],  // orthogonal to ray [p0,p2] pointing right
        r      = [(p2-p1).y, (p1-p2).x],  // orthogonal to ray [p2,p1] pointing right
        s      = [(p1-p0).y, (p0-p1).x],  // orthogonal to ray [p1,p0] pointing right
        inside = [for(p=select(poly,to_tst)) // for vertices other than p0, p1 and p2
                      if( (p-p0)*q<=0 && (p-p2)*r<=0 && (p-p1)*s<=0  // p is on the triangle
                          && norm(p-p0)>eps  // but not on any vertex of it
                          && norm(p-p1)>eps  
                          && norm(p-p2)>eps ) 
                          p ]                       
    )
    inside==[] ? _i : // found an ear
    // check the next ear candidate
    _get_ear(poly, ind, eps, _i=_i+1);


// true for some specific kinds of degeneracy
function _is_degenerate(tri,eps) =
       norm(tri[0]-tri[1])<eps || norm(tri[1]-tri[2])<eps || norm(tri[2]-tri[0])<eps ;


function _is_cw2(a,b,c,eps=EPSILON) = cross(a-c,b-c)<eps*norm(a-c)*norm(b-c);



// Function: is_polygon_clockwise()
// Usage:
//   test = is_polygon_clockwise(poly);
// Topics: Geometry, Polygons, Clockwise
// See Also: clockwise_polygon(), ccw_polygon(), reverse_polygon()
// Description:
//   Return true if the given 2D simple polygon is in clockwise order, false otherwise.
//   Results for complex (self-intersecting) polygon are indeterminate.
// Arguments:
//   poly = The list of 2D path points for the perimeter of the polygon.

// For algorithm see 2.07 here: http://www.faqs.org/faqs/graphics/algorithms-faq/
function is_polygon_clockwise(poly) =
    assert(is_path(poly,dim=2), "Input should be a 2d path")
    let(
        minx = min(poly*[1,0]),
        lowind = search(minx, poly, 0, 0),
        lowpts = select(poly,lowind),
        miny = min(lowpts*[0,1]),
        extreme_sub = search(miny, lowpts, 1, 1)[0],
        extreme = lowind[extreme_sub]
    )
    cross(select(poly,extreme+1)-poly[extreme],
          select(poly,extreme-1)-poly[extreme])<0;


// Function: clockwise_polygon()
// Usage:
//   newpoly = clockwise_polygon(poly);
// Topics: Geometry, Polygons, Clockwise
// See Also: is_polygon_clockwise(), ccw_polygon(), reverse_polygon()
// Description:
//   Given a 2D polygon path, returns the clockwise winding version of that path.
// Arguments:
//   poly = The list of 2D path points for the perimeter of the polygon.
function clockwise_polygon(poly) =
    assert(is_path(poly,dim=2), "Input should be a 2d polygon")
    polygon_area(poly, signed=true)<0 ? poly : reverse_polygon(poly);


// Function: ccw_polygon()
// Usage:
//   newpoly = ccw_polygon(poly);
// See Also: is_polygon_clockwise(), clockwise_polygon(), reverse_polygon()
// Topics: Geometry, Polygons, Clockwise
// Description:
//   Given a 2D polygon poly, returns the counter-clockwise winding version of that poly.
// Arguments:
//   poly = The list of 2D path points for the perimeter of the polygon.
function ccw_polygon(poly) =
    assert(is_path(poly,dim=2), "Input should be a 2d polygon")
    polygon_area(poly, signed=true)<0 ? reverse_polygon(poly) : poly;


// Function: reverse_polygon()
// Usage:
//   newpoly = reverse_polygon(poly)
// Topics: Geometry, Polygons, Clockwise
// See Also: is_polygon_clockwise(), ccw_polygon(), clockwise_polygon()
// Description:
//   Reverses a polygon's winding direction, while still using the same start point.
// Arguments:
//   poly = The list of the path points for the perimeter of the polygon.
function reverse_polygon(poly) =
    let(poly=force_path(poly,"poly"))
    assert(is_path(poly), "Input should be a polygon")
    [ poly[0], for(i=[len(poly)-1:-1:1]) poly[i] ];



// Function: polygon_shift()
// Usage:
//   newpoly = polygon_shift(poly, i);
// Topics: Geometry, Polygons
// Description:
//   Given a polygon `poly`, rotates the point ordering so that the first point in the polygon path is the one at index `i`.
//   This is identical to `list_rotate` except that it checks for doubled endpoints and removed them if present.  
// Arguments:
//   poly = The list of points in the polygon path.
//   i = The index of the point to shift to the front of the path.
// Example:
//   polygon_shift([[3,4], [8,2], [0,2], [-4,0]], 2);   // Returns [[0,2], [-4,0], [3,4], [8,2]]
function polygon_shift(poly, i) =
    let(poly=force_path(poly,"poly"))
    assert(is_path(poly), "Invalid polygon." )
    list_rotate(cleanup_path(poly), i);



// Function: reindex_polygon()
// Usage:
//   newpoly = reindex_polygon(reference, poly);
// Topics: Geometry, Polygons
// Description:
//   Rotates and possibly reverses the point order of a 2d or 3d polygon path to optimize its pairwise point
//   association with a reference polygon.  The two polygons must have the same number of vertices and be the same dimension.
//   The optimization is done by computing the distance, norm(reference[i]-poly[i]), between
//   corresponding pairs of vertices of the two polygons and choosing the polygon point index rotation that
//   makes the total sum over all pairs as small as possible.  Returns the reindexed polygon.  Note
//   that the geometry of the polygon is not changed by this operation, just the labeling of its
//   vertices.  If the input polygon is 2d and is oriented opposite the reference then its point order is
//   reversed.
// Arguments:
//   reference = reference polygon path
//   poly = input polygon to reindex
// Example(2D):  The red dots show the 0th entry in the two input path lists.  Note that the red dots are not near each other.  The blue dot shows the 0th entry in the output polygon
//   pent = subdivide_path([for(i=[0:4])[sin(72*i),cos(72*i)]],30);
//   circ = circle($fn=30,r=2.2);
//   reindexed = reindex_polygon(circ,pent);
//   move_copies(concat(circ,pent)) circle(r=.1,$fn=32);
//   color("red") move_copies([pent[0],circ[0]]) circle(r=.1,$fn=32);
//   color("blue") translate(reindexed[0])circle(r=.1,$fn=32);
// Example(2D): The indexing that minimizes the total distance will not necessarily associate the nearest point of `poly` with the reference, as in this example where again the blue dot indicates the 0th entry in the reindexed result.
//   pent = move([3.5,-1],p=subdivide_path([for(i=[0:4])[sin(72*i),cos(72*i)]],30));
//   circ = circle($fn=30,r=2.2);
//   reindexed = reindex_polygon(circ,pent);
//   move_copies(concat(circ,pent)) circle(r=.1,$fn=32);
//   color("red") move_copies([pent[0],circ[0]]) circle(r=.1,$fn=32);
//   color("blue") translate(reindexed[0])circle(r=.1,$fn=32);
function reindex_polygon(reference, poly, return_error=false) =
    let(reference=force_path(reference,"reference"),
        poly=force_path(poly,"poly"))
    assert(is_path(reference) && is_path(poly,dim=len(reference[0])),
           "Invalid polygon(s) or incompatible dimensions. " )
    assert(len(reference)==len(poly), "The polygons must have the same length.")
    let(
        dim = len(reference[0]),
        N = len(reference),
        fixpoly = dim != 2? poly :
                  is_polygon_clockwise(reference)
                  ? clockwise_polygon(poly)
                  : ccw_polygon(poly),
        I   = [for(i=reference) 1],
        val = [ for(k=[0:N-1])
                    [for(i=[0:N-1])
                      norm(reference[i]-fixpoly[(i+k)%N]) ] ]*I,
        min_ind = min_index(val),
        optimal_poly = polygon_shift(fixpoly, min_ind)
    )
    return_error? [optimal_poly, val[min_ind]] :
    optimal_poly;


// Function: align_polygon()
// Usage:
//   newpoly = align_polygon(reference, poly, [angles], [cp], [tran], [return_ind]);
// Topics: Geometry, Polygons
// Description:
//   Find the best alignment of a specified 2D polygon with a reference 2D polygon over a set of
//   transformations.  You can specify a list or range of angles and a centerpoint or you can
//   give a list of arbitrary 2d transformation matrices.  For each transformation or angle, the polygon is
//   reindexed, which is a costly operation so if run time is a problem, use a smaller sampling of angles or
//   transformations.  By default returns the rotated and reindexed polygon.  You can also request that
//   the best angle or the index into the transformation list be returned.  When you specify an angle
// Arguments:
//   reference = reference polygon
//   poly = polygon to rotate into alignment with the reference
//   angles = list or range of angles to test
//   cp = centerpoint for rotations
//   ---
//   tran = list of 2D transformation matrices to optimize over
//   return_ind = if true, return the best angle (if you specified angles) or the index into tran otherwise of best alignment
// Example(2D): Rotating the poorly aligned light gray triangle by 105 degrees produces the best alignment, shown in blue:
//   ellipse = yscale(3,circle(r=10, $fn=32));
//   tri = move([-50/3,-9],
//              subdivide_path([[0,0], [50,0], [0,27]], 32));
//   aligned = align_polygon(ellipse,tri, [0:5:180]);
//   color("white")stroke(tri,width=.5,closed=true);
//   stroke(ellipse, width=.5, closed=true);
//   color("blue")stroke(aligned,width=.5,closed=true);
// Example(2D,NoAxes): Translating a triangle (light gray) to the best alignment (blue)
//   ellipse = yscale(2,circle(r=10, $fn=32));
//   tri = subdivide_path([[0,0], [27,0], [-7,50]], 32);
//   T = [for(x=[-10:0], y=[-30:-15]) move([x,y])];
//   aligned = align_polygon(ellipse,tri, trans=T);
//   color("white")stroke(tri,width=.5,closed=true);
//   stroke(ellipse, width=.5, closed=true);
//   color("blue")stroke(aligned,width=.5,closed=true);
function align_polygon(reference, poly, angles, cp, trans, return_ind=false) =
    let(reference=force_path(reference,"reference"),
        poly=force_path(poly,"poly"))
    assert(is_undef(trans) || (is_undef(angles) && is_undef(cp)), "Cannot give both angles/cp and trans as input")
    let(
        trans = is_def(trans) ? trans :
            assert( (is_vector(angles) && len(angles)>0) || valid_range(angles),
                "The `angle` parameter must be a range or a non void list of numbers.")
            [for(angle=angles) zrot(angle,cp=cp)]
    )
    assert(is_path(reference,dim=2), "reference must be a 2D polygon")
    assert(is_path(poly,dim=2), "poly must be a 2D polygon")
    assert(len(reference)==len(poly), "The polygons must have the same length.")
    let(     // alignments is a vector of entries of the form: [polygon, error]
        alignments = [
            for(T=trans)
              reindex_polygon(
                  reference,
                  apply(T,poly),
                  return_error=true
              )
        ],
        scores = column(alignments,1),
        minscore = min(scores),
        minind = [for(i=idx(scores)) if (scores[i]<minscore+EPSILON) i],
        dummy = is_def(angles) ? echo(best_angles = select(list(angles), minind)):0,
        best = minind[0]
    )
    return_ind ? (is_def(angles) ? list(angles)[best] : best)
    : alignments[best][0];
    

// Function: are_polygons_equal()
// Usage:
//    b = are_polygons_equal(poly1, poly2, [eps])
// Description:
//    Returns true if poly1 and poly2 are the same polongs
//    within given epsilon tolerance.
// Arguments:
//    poly1 = first polygon
//    poly2 = second polygon
//    eps = tolerance for comparison
// Example(NORENDER):
//    are_polygons_equal(pentagon(r=4),
//                   rot(360/5, p=pentagon(r=4))); // returns true
//    are_polygons_equal(pentagon(r=4),
//                   rot(90, p=pentagon(r=4)));    // returns false
function are_polygons_equal(poly1, poly2, eps=EPSILON) =
    let(
        poly1 = cleanup_path(poly1),
        poly2 = cleanup_path(poly2),
        l1 = len(poly1),
        l2 = len(poly2)
    ) l1 != l2 ? false :
    let( maybes = find_approx(poly1[0], poly2, eps=eps, all=true) )
    maybes == []? false :
    [for (i=maybes) if (_are_polygons_equal(poly1, poly2, eps, i)) 1] != [];

function _are_polygons_equal(poly1, poly2, eps, st) =
    max([for(d=poly1-select(poly2,st,st-1)) d*d])<eps*eps;


// Function: is_polygon_in_list()
// Topics: Polygons, Comparators
// See Also: are_polygons_equal(), are_regions_equal()
// Usage:
//   bool = is_polygon_in_list(poly, polys);
// Description:
//   Returns true if one of the polygons in `polys` is equivalent to the polygon `poly`.
// Arguments:
//   poly = The polygon to search for.
//   polys = The list of polygons to look for the polygon in.
function is_polygon_in_list(poly, polys) =
    __is_polygon_in_list(poly, polys, 0);

function __is_polygon_in_list(poly, polys, i) =
    i >= len(polys)? false :
    are_polygons_equal(poly, polys[i])? true :
    __is_polygon_in_list(poly, polys, i+1);



// Section: Convex Sets


// Function: is_polygon_convex()
// Usage:
//   test = is_polygon_convex(poly);
// Topics: Geometry, Convexity, Test
// Description:
//   Returns true if the given 2D or 3D polygon is convex.
//   The result is meaningless if the polygon is not simple (self-crossing) or non coplanar.
//   If the points are collinear or not coplanar an error may be generated.
// Arguments:
//   poly = Polygon to check.
//   eps = Tolerance for the collinearity and coplanarity tests. Default: EPSILON.
// Example:
//   test1 = is_polygon_convex(circle(d=50));                                 // Returns: true
//   test2 = is_polygon_convex(rot([50,120,30], p=path3d(circle(1,$fn=50)))); // Returns: true
//   spiral = [for (i=[0:36]) let(a=-i*10) (10+i)*[cos(a),sin(a)]];
//   test = is_polygon_convex(spiral);                                        // Returns: false
function is_polygon_convex(poly,eps=EPSILON) =
    assert(is_path(poly), "The input should be a 2D or 3D polygon." )
    let(
        lp = len(poly),
        p0 = poly[0]
    )
    assert( lp>=3 , "A polygon must have at least 3 points" )
    let( crosses = [for(i=[0:1:lp-1]) cross(poly[(i+1)%lp]-poly[i], poly[(i+2)%lp]-poly[(i+1)%lp]) ] )
    len(p0)==2
      ? let( size = max([for(p=poly) norm(p-p0)]), tol=pow(size,2)*eps )
        assert( size>eps, "The polygon is self-crossing or its points are collinear" )
        min(crosses) >=-tol || max(crosses)<=tol
      : let( ip = noncollinear_triple(poly,error=false,eps=eps) )
        assert( ip!=[], "The points are collinear")
        let( 
            crx   = cross(poly[ip[1]]-poly[ip[0]],poly[ip[2]]-poly[ip[1]]),
            nrm   = crx/norm(crx),
            plane = concat(nrm, nrm*poly[0]), 
            prod  = crosses*nrm,
            size  = norm(poly[ip[1]]-poly[ip[0]]),
            tol   = pow(size,2)*eps
        )
        assert(_pointlist_greatest_distance(poly,plane) < size*eps, "The polygon points are not coplanar")
        let(
            minc = min(prod),
            maxc = max(prod) ) 
        minc>=-tol || maxc<=tol;


// Function: convex_distance()
// Usage:
//   dist = convex_distance(pts1, pts2,[eps=]);
// Topics: Geometry, Convexity, Distance
// See also: 
//   convex_collision(), hull()
// Description:
//   Returns the smallest distance between a point in convex hull of `points1`
//   and a point in the convex hull of `points2`. All the points in the lists
//   should have the same dimension, either 2D or 3D.
//   A zero result means the hulls intercept whithin a tolerance `eps`.
// Arguments:
//   points1 = first list of 2d or 3d points.
//   points2 = second list of 2d or 3d points.
//   eps = tolerance in distance evaluations. Default: EPSILON.
// Example(2D):
//    pts1 = move([-3,0], p=square(3,center=true));
//    pts2 = rot(a=45, p=square(2,center=true));
//    pts3 = [ [2,0], [1,2],[3,2], [3,-2], [1,-2] ];
//    polygon(pts1);
//    polygon(pts2);
//    polygon(pts3);
//    echo(convex_distance(pts1,pts2)); // Returns: 0.0857864
//    echo(convex_distance(pts2,pts3)); // Returns: 0
// Example(3D):
//    sphr1 = sphere(2,$fn=10);
//    sphr2 = move([4,0,0], p=sphr1);
//    sphr3 = move([4.5,0,0], p=sphr1);
//    vnf_polyhedron(sphr1);
//    vnf_polyhedron(sphr2);
//    echo(convex_distance(sphr1[0], sphr2[0])); // Returns: 0
//    echo(convex_distance(sphr1[0], sphr3[0])); // Returns: 0.5
function convex_distance(points1, points2, eps=EPSILON) =
    assert(is_matrix(points1) && is_matrix(points2,undef,len(points1[0])), 
           "The input lists should be compatible consistent non empty lists of points.")
    assert(len(points1[0])==2 || len(points1[0])==3 ,
           "The input points should be 2d or 3d points.")
    let( d = points1[0]-points2[0] )
    norm(d)<eps ? 0 :
    let( v = _support_diff(points1,points2,-d) )
    norm(_GJK_distance(points1, points2, eps, 0, v, [v]));


// Finds the vector difference between the hulls of the two pointsets by the GJK algorithm
// Based on:
// http://www.dtecta.com/papers/jgt98convex.pdf
function _GJK_distance(points1, points2, eps=EPSILON, lbd, d, simplex=[]) =
    let( nrd = norm(d) ) // distance upper bound
    nrd<eps ? d :
    let(
        v     = _support_diff(points1,points2,-d),
        lbd   = max(lbd, d*v/nrd), // distance lower bound
        close = (nrd-lbd <= eps*nrd)
    )
    close ? d :
    let( newsplx = _closest_simplex(concat(simplex,[v]),eps) )
    _GJK_distance(points1, points2, eps, lbd, newsplx[0], newsplx[1]);


// Function: convex_collision()
// Usage:
//   test = convex_collision(pts1, pts2, [eps=]);
// Topics: Geometry, Convexity, Collision, Intersection
// See also: 
//   convex_distance(), hull()
// Description:
//   Returns `true` if the convex hull of `points1` intercepts the convex hull of `points2`
//   otherwise, `false`.
//   All the points in the lists should have the same dimension, either 2D or 3D.
//   This function is tipically faster than `convex_distance` to find a non-collision.
// Arguments:
//   points1 = first list of 2d or 3d points.
//   points2 = second list of 2d or 3d points.
//   eps - tolerance for the intersection tests. Default: EPSILON.
// Example(2D):
//    pts1 = move([-3,0], p=square(3,center=true));
//    pts2 = rot(a=45, p=square(2,center=true));
//    pts3 = [ [2,0], [1,2],[3,2], [3,-2], [1,-2] ];
//    polygon(pts1);
//    polygon(pts2);
//    polygon(pts3);
//    echo(convex_collision(pts1,pts2)); // Returns: false
//    echo(convex_collision(pts2,pts3)); // Returns: true
// Example(3D):
//    sphr1 = sphere(2,$fn=10);
//    sphr2 = move([4,0,0], p=sphr1);
//    sphr3 = move([4.5,0,0], p=sphr1);
//    vnf_polyhedron(sphr1);
//    vnf_polyhedron(sphr2);
//    echo(convex_collision(sphr1[0], sphr2[0])); // Returns: true
//    echo(convex_collision(sphr1[0], sphr3[0])); // Returns: false
//
function convex_collision(points1, points2, eps=EPSILON) =
    assert(is_matrix(points1) && is_matrix(points2,undef,len(points1[0])), 
           "The input lists should be compatible consistent non empty lists of points.")
    assert(len(points1[0])==2 || len(points1[0])==3 ,
           "The input points should be 2d or 3d points.")
    let( d = points1[0]-points2[0] )
    norm(d)<eps ? true :
    let( v = _support_diff(points1,points2,-d) )
    _GJK_collide(points1, points2, v, [v], eps);


// Based on the GJK collision algorithms found in:
// http://uu.diva-portal.org/smash/get/diva2/FFULLTEXT01.pdf
// or
// http://www.dtecta.com/papers/jgt98convex.pdf
function _GJK_collide(points1, points2, d, simplex, eps=EPSILON) =
    norm(d) < eps ? true :          // does collide
    let( v = _support_diff(points1,points2,-d) ) 
    v*d > eps*eps ? false : // no collision
    let( newsplx = _closest_simplex(concat(simplex,[v]),eps) )
    norm(v-newsplx[0])<eps ? norm(v)<eps :
    _GJK_collide(points1, points2, newsplx[0], newsplx[1], eps);


// given a simplex s, returns a pair:
//  - the point of the s closest to the origin
//  - the smallest sub-simplex of s that contains that point
function _closest_simplex(s,eps=EPSILON) =
    len(s)==2 ? _closest_s1(s,eps) :
    len(s)==3 ? _closest_s2(s,eps) :
    len(s)==4 ? _closest_s3(s,eps) :
    assert(false, "Internal error.");


// find the point of a 1-simplex closest to the origin
function _closest_s1(s,eps=EPSILON) =
    norm(s[1]-s[0])<=eps*(norm(s[0])+norm(s[1]))/2 ? [ s[0], [s[0]] ] :
    let(
        c = s[1]-s[0],
        t = -s[0]*c/(c*c)
    )
    t<0 ? [ s[0], [s[0]] ] :
    t>1 ? [ s[1], [s[1]] ] :
    [ s[0]+t*c, s ];


// find the point of a 2-simplex closest to the origin
function _closest_s2(s, eps=EPSILON) =
    // considering that s[2] was the last inserted vertex in s by GJK, 
    // the plane orthogonal to the triangle [ origin, s[0], s[1] ] that 
    // contains [s[0],s[1]] have the origin and s[2] on the same side;
    // that reduces the cases to test and the only possible simplex
    // outcomes are s, [s[0],s[2]] and [s[1],s[2]] 
    let(
        area  = cross(s[2]-s[0], s[1]-s[0]), 
        area2 = area*area                     // tri area squared
    )
    area2<=eps*max([for(si=s) pow(si*si,2)]) // degenerate tri
    ?   norm(s[2]-s[0]) < norm(s[2]-s[1]) 
        ? _closest_s1([s[1],s[2]])
        : _closest_s1([s[0],s[2]])
    :   let(
            crx1  = cross(s[0], s[2])*area,
            crx2  = cross(s[1], s[0])*area,
            crx0  = cross(s[2], s[1])*area
        )
        // all have the same signal -> origin projects inside the tri 
        max(crx1, crx0, crx2) < 0  || min(crx1, crx0, crx2) > 0
        ?   // baricentric coords of projection   
            [ [abs(crx0),abs(crx1),abs(crx2)]*s/area2, s ] 
       :   let( 
               cl12 = _closest_s1([s[1],s[2]]),
               cl02 = _closest_s1([s[0],s[2]])
            )
            norm(cl12[0])<norm(cl02[0]) ? cl12 : cl02;
        

// find the point of a 3-simplex closest to the origin
function _closest_s3(s,eps=EPSILON) =
    let( nr = cross(s[1]-s[0],s[2]-s[0]),
         sz = [ norm(s[0]-s[1]), norm(s[1]-s[2]), norm(s[2]-s[0]) ] )
    norm(nr)<=eps*pow(max(sz),2)
    ?   let( i = max_index(sz) )
        _closest_s2([ s[i], s[(i+1)%3], s[3] ], eps) // degenerate case
    :   // considering that s[3] was the last inserted vertex in s by GJK,
        // the only possible outcomes will be:
        //    s or some of the 3 faces of s containing s[3]
        let(
            tris = [ [s[0], s[1], s[3]],
                     [s[1], s[2], s[3]],
                     [s[2], s[0], s[3]] ],
            cntr = sum(s)/4,
            // indicator of the tris facing the origin
            facing = [for(i=[0:2])
                        let( nrm = _tri_normal(tris[i]) )
                        if( ((nrm*(s[i]-cntr))>0)==(nrm*s[i]<0) ) i ]
        )
        len(facing)==0 ? [ [0,0,0], s ] : // origin is inside the simplex
        len(facing)==1 ? _closest_s2(tris[facing[0]], eps) :
        let( // look for the origin-facing tri closest to the origin
            closest = [for(i=facing) _closest_s2(tris[i], eps) ],
            dist    = [for(cl=closest) norm(cl[0]) ],
            nearest = min_index(dist) 
        )
        closest[nearest];


function _tri_normal(tri) = cross(tri[1]-tri[0],tri[2]-tri[0]);


function _support_diff(p1,p2,d) =
    let( p1d = p1*d, p2d = p2*d )
    p1[search(max(p1d),p1d,1)[0]] - p2[search(min(p2d),p2d,1)[0]];


// Section: Rotation Decoding

// Function: rot_decode()
// Usage:
//   info = rot_decode(rotation,[long]); // Returns: [angle,axis,cp,translation]
// Topics: Affine, Matrices, Transforms
// Description:
//   Given an input 3D rigid transformation operator (one composed of just rotations and translations) represented
//   as a 4x4 matrix, compute the rotation and translation parameters of the operator.  Returns a list of the
//   four parameters, the angle, in the interval [0,180], the rotation axis as a unit vector, a centerpoint for
//   the rotation, and a translation.  If you set `parms = rot_decode(rotation)` then the transformation can be
//   reconstructed from parms as `move(parms[3]) * rot(a=parms[0],v=parms[1],cp=parms[2])`.  This decomposition
//   makes it possible to perform interpolation.  If you construct a transformation using `rot` the decoding
//   may flip the axis (if you gave an angle outside of [0,180]).  The returned axis will be a unit vector, and
//   the centerpoint lies on the plane through the origin that is perpendicular to the axis.  It may be different
//   than the centerpoint you used to construct the transformation.
//   .
//   If you set `long` to true then return the reversed rotation, with the angle in [180,360].
// Arguments:
//   rotation = rigid transformation to decode
//   long = if true return the "long way" around, with the angle in [180,360].  Default: false
// Example:
//   info = rot_decode(rot(45));
//          // Returns: [45, [0,0,1], [0,0,0], [0,0,0]]
//   info = rot_decode(rot(a=37, v=[1,2,3], cp=[4,3,-7])));
//          // Returns: [37, [0.26, 0.53, 0.80], [4.8, 4.6, -4.6], [0,0,0]]
//   info = rot_decode(left(12)*xrot(-33));
//          // Returns: [33, [-1,0,0], [0,0,0], [-12,0,0]]
//   info = rot_decode(translate([3,4,5]));
//          // Returns: [0, [0,0,1], [0,0,0], [3,4,5]]
function rot_decode(M,long=false) =
    assert(is_matrix(M,4,4) && approx(M[3],[0,0,0,1]), "Input matrix must be a 4x4 matrix representing a 3d transformation")
    let(R = submatrix(M,[0:2],[0:2]))
    assert(approx(det3(R),1) && approx(norm_fro(R * transpose(R)-ident(3)),0),"Input matrix is not a rotation")
    let(
        translation = [for(row=[0:2]) M[row][3]],   // translation vector
        largest  = max_index([R[0][0], R[1][1], R[2][2]]),
        axis_matrix = R + transpose(R) - (matrix_trace(R)-1)*ident(3),   // Each row is on the rotational axis
            // Construct quaternion q = c * [x sin(theta/2), y sin(theta/2), z sin(theta/2), cos(theta/2)]
        q_im = axis_matrix[largest],
        q_re = R[(largest+2)%3][(largest+1)%3] - R[(largest+1)%3][(largest+2)%3],
        c_sin = norm(q_im),              // c * sin(theta/2) for some c
        c_cos = abs(q_re)                // c * cos(theta/2)
    )
    approx(c_sin,0) ? [0,[0,0,1],[0,0,0],translation] :
    let(
        angle = 2*atan2(c_sin, c_cos),    // This is supposed to be more accurate than acos or asin
        axis  = (q_re>=0 ? 1:-1)*q_im/c_sin,
        tproj = translation - (translation*axis)*axis,    // Translation perpendicular to axis determines centerpoint
        cp    = (tproj + cross(axis,tproj)*c_cos/c_sin)/2
    )
    [long ? 360-angle:angle,
     long? -axis : axis,
     cp,
     (translation*axis)*axis];




// vim: expandtab tabstop=4 shiftwidth=4 softtabstop=4 nowrap
