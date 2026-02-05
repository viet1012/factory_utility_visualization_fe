import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { STLLoader } from "three/examples/jsm/loaders/STLLoader.js";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";

const canvas = document.getElementById("c");
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
renderer.setPixelRatio(window.devicePixelRatio);

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x111111);

const camera = new THREE.PerspectiveCamera(50, 1, 0.01, 5000);
camera.position.set(0, 0, 200);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;

scene.add(new THREE.AmbientLight(0xffffff, 0.6));
const dir = new THREE.DirectionalLight(0xffffff, 0.9);
dir.position.set(2, 3, 4);
scene.add(dir);

function resize() {
  const w = window.innerWidth;
  const h = window.innerHeight;
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
}
window.addEventListener("resize", resize);
resize();

// ✅ file STL phải nằm cùng folder viewer/ (đúng như bạn để)
const MODEL_URL = "./part1.stl";

function frameObject(obj) {
  const box = new THREE.Box3().setFromObject(obj);
  const size = box.getSize(new THREE.Vector3());
  const center = box.getCenter(new THREE.Vector3());

  obj.position.sub(center);

  const maxSize = Math.max(size.x, size.y, size.z);
  const dist = maxSize * 1.6;

  camera.position.set(0, 0, dist);
  controls.target.set(0, 0, 0);
  controls.update();
}

function loadSTL(url) {
  const loader = new STLLoader();
  loader.load(url, (geo) => {
    geo.computeVertexNormals();
    const mat = new THREE.MeshStandardMaterial({ color: 0xb0b0b0, metalness: 0.15, roughness: 0.6 });
    const mesh = new THREE.Mesh(geo, mat);
    scene.add(mesh);
    frameObject(mesh);
  }, undefined, (err) => console.error("STL load error:", err));
}

function loadGLB(url) {
  const loader = new GLTFLoader();
  loader.load(url, (gltf) => {
    const obj = gltf.scene;
    scene.add(obj);
    frameObject(obj);
  }, undefined, (err) => console.error("GLB load error:", err));
}

if (MODEL_URL.toLowerCase().endsWith(".stl")) loadSTL(MODEL_URL);
else loadGLB(MODEL_URL);

function animate() {
  requestAnimationFrame(animate);
  controls.update();
  renderer.render(scene, camera);
}
animate();
