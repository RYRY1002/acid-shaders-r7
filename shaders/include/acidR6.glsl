vec3 Acid(vec3 position) {
  locposition = gbufferModelViewInverse * locposition;

  float distance2D = locposition.z * locposition.z + locposition.x * locposition.x;

  locposition.y += 5.0 * sin(distance2D * sin((frameTimeCounter * 20 + 36000.0) / 143.0) / 1000.0);

  float z = locposition.z;
  float y = locposition.y;

  float om = sin(distance2D * sin((frameTimeCounter * 20.0 + 36000.0) / 256.0) / 5000.0) * sin((frameTimeCounter * 20.0 + 36000.0) / 200.0);

  position.z = y * sin(om) + z * cos(om);
  position.y = y * cos(om) - z * sin(om);

  locposition = gbufferModelView * locposition;

  return position;
}
