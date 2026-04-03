import sys
import numpy as np
import matplotlib
from PyQt6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                             QHBoxLayout, QPushButton, QLabel, QComboBox, 
                             QMessageBox, QTableWidget, QTableWidgetItem, QHeaderView,
                             QGroupBox, QSlider)
from PyQt6.QtCore import Qt, QTimer

matplotlib.use('qtagg')
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure

import shapely
from shapely.geometry import Polygon, LineString, MultiLineString, MultiPolygon
from shapely.ops import split, unary_union
from shapely import affinity

# Configuración
DRONE_SPEED = 5.0  # m/s
TURN_PENALTY = 2.0  # seconds per turn
SWEEP_WIDTH = 2.0  # meters between parallel paths

class MplCanvas(FigureCanvas):
    def __init__(self, parent=None, width=6, height=5, dpi=100):
        self.fig = Figure(figsize=(width, height), dpi=dpi)
        self.axes = self.fig.add_subplot(111)
        self.axes.set_title("Carte de Planification (1 unité = 1 m)")
        self.axes.set_xlim(0, 100)
        self.axes.set_ylim(0, 100)
        self.axes.set_aspect('equal')
        self.axes.grid(True)
        super(MplCanvas, self).__init__(self.fig)

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Simulateur d'Itinéraires pour Drones - Zones Complexes")
        self.setMinimumSize(1000, 700)
        
        # Estados: DRAWING_MAIN, DRAWING_RESTR, READY
        self.state = "DRAWING_MAIN" 
        self.main_points = []
        self.main_polygon = None
        
        self.restriction_polygons = []
        self.current_restr_points = []
        
        self.operable_area = None
        self.subdivision_cells = [] # Geometrías subdivididas

        self.setup_ui()

    def setup_ui(self):
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        layout = QHBoxLayout(main_widget)

        # Panel Izquierdo: Mapa
        self.canvas = MplCanvas(self, width=6, height=6, dpi=100)
        layout.addWidget(self.canvas, stretch=2)
        
        self.canvas.mpl_connect('button_press_event', self.on_click)

        # Panel Derecho: Controles
        right_panel = QWidget()
        right_layout = QVBoxLayout(right_panel)

        # -- Grupo: Herramientas de Dibujo --
        group_draw = QGroupBox("1. Contrôles du Terrain")
        draw_layout = QVBoxLayout(group_draw)
        
        self.lbl_status = QLabel("Statut : Dessin de la Zone Principale (clics infinis)")
        self.lbl_status.setStyleSheet("font-weight: bold; color: blue;")
        self.lbl_status.setWordWrap(True)
        draw_layout.addWidget(self.lbl_status)

        self.btn_close_main = QPushButton("Terminer la Zone Principale")
        self.btn_close_main.clicked.connect(self.close_main_area)
        self.btn_close_main.setEnabled(False)
        draw_layout.addWidget(self.btn_close_main)

        self.btn_add_restr = QPushButton("Ajouter Zone d'Obstacle/Restriction")
        self.btn_add_restr.clicked.connect(self.add_restriction)
        self.btn_add_restr.setEnabled(False)
        draw_layout.addWidget(self.btn_add_restr)

        self.btn_close_restr = QPushButton("Fermer le Polygone de Restriction")
        self.btn_close_restr.clicked.connect(self.close_restriction)
        self.btn_close_restr.setEnabled(False)
        draw_layout.addWidget(self.btn_close_restr)

        self.btn_reset = QPushButton("Tout Réinitialiser")
        self.btn_reset.clicked.connect(self.reset_points)
        draw_layout.addWidget(self.btn_reset)
        
        right_layout.addWidget(group_draw)

        # -- Grupo: Planeación --
        group_plan = QGroupBox("2. Planification d'Itinéraire")
        plan_layout = QVBoxLayout(group_plan)

        lbl_algo = QLabel("Sélectionnez une Méthode :")
        plan_layout.addWidget(lbl_algo)
        
        self.combo_algo = QComboBox()
        self.combo_algo.addItems([
            "Grille Horizontale (Balayage Complet)", 
            "Grille Verticale (Balayage Complet)",
            "Grille Diagonale (45°)",
            "Méthode Spirale/Périmétrale", 
            "Subdivision de Zones Polygonales",
            "Linéaire avec Points (Périmètre Extérieur)"
        ])
        plan_layout.addWidget(self.combo_algo)

        self.btn_generate = QPushButton("Générer le Meilleur Itinéraire")
        self.btn_generate.clicked.connect(self.generate_path)
        self.btn_generate.setEnabled(False)
        self.btn_generate.setStyleSheet("background-color: #4CAF50; color: white; padding: 10px; font-weight: bold;")
        plan_layout.addWidget(self.btn_generate)
        
        right_layout.addWidget(group_plan)

        # -- Grupo: Resultados --
        group_res = QGroupBox("3. Comparaison et Temps")
        res_layout = QVBoxLayout(group_res)

        self.table = QTableWidget(6, 2)
        self.table.setHorizontalHeaderLabels(["Distance (m)", "Temps Est. (s)"])
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.table.setVerticalHeaderLabels(["Horizontal", "Vertical", "Diagonal", "Spirale", "Subdivision", "Périmétral"])
        res_layout.addWidget(self.table)
        
        right_layout.addWidget(group_res)

        # -- Grupo: Simulación --
        group_sim = QGroupBox("4. Simulation Visuelle")
        sim_layout = QVBoxLayout(group_sim)
        
        self.btn_play = QPushButton("▶ Lire le Vol")
        self.btn_play.clicked.connect(self.play_simulation)
        self.btn_play.setEnabled(False)
        self.btn_play.setStyleSheet("background-color: #2196F3; color: white; padding: 10px; font-weight: bold;")
        sim_layout.addWidget(self.btn_play)
        
        lbl_speed = QLabel("Vitesse de lecture :")
        sim_layout.addWidget(lbl_speed)
        
        self.slider_speed = QSlider(Qt.Orientation.Horizontal)
        self.slider_speed.setMinimum(1)
        self.slider_speed.setMaximum(50)
        self.slider_speed.setValue(10)
        self.slider_speed.valueChanged.connect(self.update_timer_interval)
        sim_layout.addWidget(self.slider_speed)
        
        right_layout.addWidget(group_sim)
        
        right_layout.addStretch()
        layout.addWidget(right_panel, stretch=1)

    def on_click(self, event):
        if event.inaxes != self.canvas.axes: return
        x, y = event.xdata, event.ydata
        
        if self.state == "DRAWING_MAIN":
            self.main_points.append((x, y))
            if len(self.main_points) >= 3:
                self.btn_close_main.setEnabled(True)
            self.lbl_status.setText(f"Zone Principale : {len(self.main_points)} points. Cliquez sur 'Terminer' pour fermer le polygone.")
            self.update_plot()
             
        elif self.state == "DRAWING_RESTR":
            self.current_restr_points.append((x, y))
            if len(self.current_restr_points) >= 3:
                self.btn_close_restr.setEnabled(True)
            self.lbl_status.setText(f"Restriction actuelle : {len(self.current_restr_points)} points. Cliquez sur 'Fermer' pour sauvegarder.")
            self.update_plot()

    def close_main_area(self):
        if len(self.main_points) >= 3:
            self.main_polygon = Polygon(self.main_points)
            if not self.main_polygon.is_valid:
                self.main_polygon = self.main_polygon.buffer(0) 
                if not self.main_polygon.is_valid:
                    QMessageBox.warning(self, "Erreur", "Polygone invalide (croisements complexes). Réinitialisez et réessayez.")
                    return
            
            self.compute_operable_area()
            self.state = "READY"
            self.btn_close_main.setEnabled(False)
            self.btn_add_restr.setEnabled(True)
            self.btn_generate.setEnabled(True)
            self.lbl_status.setText("Zone prête. Vous pouvez ajouter des restrictions ou générer l'itinéraire.")
            self.lbl_status.setStyleSheet("font-weight: bold; color: green;")
            self.update_plot()

    def add_restriction(self):
        self.state = "DRAWING_RESTR"
        self.current_restr_points = []
        self.btn_add_restr.setEnabled(False)
        self.btn_generate.setEnabled(False)
        self.lbl_status.setText("Mode Restriction : Dessinez l'obstacle.")
        self.lbl_status.setStyleSheet("font-weight: bold; color: red;")

    def close_restriction(self):
        if len(self.current_restr_points) >= 3:
             restr = Polygon(self.current_restr_points)
             if not restr.is_valid:
                 restr = restr.buffer(0)
             self.restriction_polygons.append(restr)
             self.current_restr_points = []
             self.compute_operable_area()
             self.state = "READY"
             self.btn_close_restr.setEnabled(False)
             self.btn_add_restr.setEnabled(True)
             self.btn_generate.setEnabled(True)
             self.lbl_status.setText(f"Restrictions actives : {len(self.restriction_polygons)}. Zone mise à jour.")
             self.lbl_status.setStyleSheet("font-weight: bold; color: green;")
             self.update_plot()

    def reset_points(self):
        self.state = "DRAWING_MAIN"
        self.main_points = []
        self.main_polygon = None
        self.restriction_polygons = []
        self.current_restr_points = []
        self.operable_area = None
        self.subdivision_cells = []
        
        self.btn_close_main.setEnabled(False)
        self.btn_add_restr.setEnabled(False)
        self.btn_close_restr.setEnabled(False)
        self.btn_generate.setEnabled(False)
        
        if hasattr(self, 'timer') and self.timer.isActive():
            self.timer.stop()
        self.btn_play.setText("▶ Lire le Vol")
        self.btn_play.setEnabled(False)
        if hasattr(self, 'drone_marker'):
            try:
                self.drone_marker.remove()
            except Exception:
                pass
            del self.drone_marker
        self.current_path = []
        
        self.lbl_status.setText("Statut : Dessin de la Zone Principale (clics infinis)")
        self.lbl_status.setStyleSheet("font-weight: bold; color: blue;")
        self.table.clearContents()
        self.update_plot()

    def compute_operable_area(self):
        if not self.main_polygon: return
        area = self.main_polygon
        if self.restriction_polygons:
            union_restr = unary_union(self.restriction_polygons)
            area = area.difference(union_restr)
        self.operable_area = area

    def plot_polygon(self, geom, fill_color, alpha_val, hatch_type=None, ec=None):
        if geom.geom_type == 'Polygon':
            xs, ys = geom.exterior.xy
            self.canvas.axes.fill(xs, ys, alpha=alpha_val, color=fill_color, hatch=hatch_type, edgecolor=ec)
            for interior in geom.interiors:
                 xs, ys = interior.xy
                 self.canvas.axes.fill(xs, ys, alpha=1.0, color='white') # Perforar hoyo grafico
        elif geom.geom_type == 'MultiPolygon':
            for g in geom.geoms:
                 self.plot_polygon(g, fill_color, alpha_val, hatch_type, ec)

    def update_plot(self):
        self.canvas.axes.clear()
        self.canvas.axes.set_title("Carte de Planification (1 unité = 1 m)")
        self.canvas.axes.set_xlim(0, 100)
        self.canvas.axes.set_ylim(0, 100)
        self.canvas.axes.set_aspect('equal')
        self.canvas.axes.grid(True)
        
        # 1. Dibujar Área Operable Final (solo si NO hay subdivisiones visibles)
        if self.operable_area and not self.operable_area.is_empty and not self.subdivision_cells:
             self.plot_polygon(self.operable_area, 'blue', 0.2)

        # 2. Dibujar Celdas de Subdivisión (cuando se aplica el algoritmo)
        if self.subdivision_cells:
            colors = ['#ffaaaa', '#aaffaa', '#aaaaff', '#ffffaa', '#ffaaff', '#aaffff', '#ffcc99', '#99ffcc']
            for i, cell in enumerate(self.subdivision_cells):
                 self.plot_polygon(cell, colors[i % len(colors)], 0.6, ec='blue')

        # 3. Dibujar Zonas de Restricción explicitas
        for rp in self.restriction_polygons:
             self.plot_polygon(rp, 'red', 0.4, hatch_type='//', ec='red')

        # 4. Dibujar polígonos en progreso (Main)
        if self.state == "DRAWING_MAIN" and self.main_points:
            xs, ys = zip(*self.main_points)
            self.canvas.axes.plot(xs, ys, "bo-", markersize=4)
            
        # 5. Dibujar polígonos en progreso (Restriction)
        if self.state == "DRAWING_RESTR" and self.current_restr_points:
            xs, ys = zip(*self.current_restr_points)
            self.canvas.axes.plot(xs, ys, "rx-", markersize=4)

        self.canvas.draw()

    # -- Lógica Geométrica de Algoritmos --
    
    def generate_path(self):
        if not self.operable_area or self.operable_area.is_empty:
            QMessageBox.warning(self, "Erreur", "La zone de vol est vide ou traversée intégralement par des restrictions.")
            return

        algo = self.combo_algo.currentIndex()
        self.subdivision_cells = [] 
        
        if algo == 4:
             self.subdivision_cells = self.cell_decomposition()

        # Calcular simulaciones
        path_grid, dist_grid, time_grid = self.calculate_grid_method()
        path_vert, dist_vert, time_vert = self.calculate_vertical_grid_global()
        path_diag, dist_diag, time_diag = self.calculate_diagonal_method()
        path_spiral, dist_spiral, time_spiral = self.calculate_spiral_method()
        path_subdiv, dist_subdiv, time_subdiv = self.calculate_subdiv_method(self.subdivision_cells if algo==4 else self.cell_decomposition())
        path_perim, dist_perim, time_perim = self.calculate_perimeter()

        self.update_table_row(0, dist_grid, time_grid)
        self.update_table_row(1, dist_vert, time_vert)
        self.update_table_row(2, dist_diag, time_diag)
        self.update_table_row(3, dist_spiral, time_spiral)
        self.update_table_row(4, dist_subdiv, time_subdiv)
        self.update_table_row(5, dist_perim, time_perim)

        self.update_plot()
        selected_path = None
        if algo == 0: selected_path = path_grid
        elif algo == 1: selected_path = path_vert
        elif algo == 2: selected_path = path_diag
        elif algo == 3: selected_path = path_spiral
        elif algo == 4: selected_path = path_subdiv
        elif algo == 5: selected_path = path_perim

        if selected_path and len(selected_path) > 0:
            self.current_path = selected_path
            self.btn_play.setEnabled(True)
            self.btn_play.setText("▶ Lire le Vol")
            if hasattr(self, 'timer') and self.timer.isActive():
                self.timer.stop()
            if hasattr(self, 'drone_marker'):
                try:
                    self.drone_marker.remove()
                except: pass
                del self.drone_marker

            px, py = zip(*selected_path)
            self.canvas.axes.plot(px, py, 'g--', linewidth=2, label='Itinéraire Drone')
            self.canvas.axes.plot(px[0], py[0], 'go', markersize=8, label='Début')
            self.canvas.axes.plot(px[-1], py[-1], 'rX', markersize=8, label='Fin')
            self.canvas.axes.legend()
            self.canvas.draw()

    def play_simulation(self):
        if not hasattr(self, 'current_path') or not self.current_path: return
        
        if hasattr(self, 'timer') and self.timer.isActive():
            self.timer.stop()
            self.btn_play.setText("▶ Lire le Vol")
            return
            
        self.btn_play.setText("⏸ Mettre la Simulation en Pause")
        
        self.sim_path = []
        for i in range(len(self.current_path) - 1):
            p1 = np.array(self.current_path[i])
            p2 = np.array(self.current_path[i+1])
            dist = np.linalg.norm(p2 - p1)
            steps = max(1, int(dist * 3))
            for step in range(steps):
                p = p1 + (p2 - p1) * (step / steps)
                self.sim_path.append(p)
        self.sim_path.append(self.current_path[-1])
        
        self.sim_idx = 0
        
        if not hasattr(self, 'drone_marker'):
            self.drone_marker, = self.canvas.axes.plot([], [], marker='X', color='black', markersize=15, linestyle='None', zorder=5)
        
        self.drone_marker.set_data([self.sim_path[0][0]], [self.sim_path[0][1]])
        self.canvas.draw()
        
        if not hasattr(self, 'timer'):
            self.timer = QTimer()
            self.timer.timeout.connect(self.update_simulation)
            
        self.update_timer_interval()
        self.timer.start()

    def update_timer_interval(self):
        if hasattr(self, 'timer'):
            speed = self.slider_speed.value()
            interval = max(5, int(1000 / (speed * 10)))
            self.timer.setInterval(interval)

    def update_simulation(self):
        speed = self.slider_speed.value()
        steps_advance = max(1, int(speed / 10))
        self.sim_idx += steps_advance
        
        if self.sim_idx >= len(self.sim_path):
            self.sim_idx = len(self.sim_path) - 1
            self.timer.stop()
            self.btn_play.setText("▶ Rejouer")
            
        p = self.sim_path[self.sim_idx]
        self.drone_marker.set_data([p[0]], [p[1]])
        self.canvas.draw_idle()

    def update_table_row(self, row, distance, time_est):
        self.table.setItem(row, 0, QTableWidgetItem(f"{distance:.2f}"))
        self.table.setItem(row, 1, QTableWidgetItem(f"{time_est:.2f}"))

    def compute_metrics(self, path):
        if not path or len(path) < 2: return 0, 0
        dist = 0
        turns = 0
        for i in range(len(path) - 1):
            p1, p2 = np.array(path[i]), np.array(path[i+1])
            d = np.linalg.norm(p2 - p1)
            dist += d
            if d > 0.1: turns += 1
        return dist, (dist / DRONE_SPEED) + (max(0, turns - 1) * TURN_PENALTY)

    def extract_vertices_x(self, geom):
        x_coords = []
        if geom.geom_type == 'Polygon':
            x_coords.extend([p[0] for p in geom.exterior.coords])
            for interior in geom.interiors:
                 x_coords.extend([p[0] for p in interior.coords])
        elif geom.geom_type == 'MultiPolygon':
            for g in geom.geoms:
                 x_coords.extend(self.extract_vertices_x(g))
        return x_coords

    def cell_decomposition(self):
        """ Divide el área en celdas basadas en los vértices del polígono y sus restricciones """
        area = self.operable_area
        if not area or area.is_empty: return []
        
        xs = sorted(list(set(self.extract_vertices_x(area))))
        # Filtrar vértices X que estén muuuuy cerca para evitar errores booleanos y celdas delgadas (threshold: 3 metros)
        fxs = [xs[0]]
        for x in xs[1:]:
             if x - fxs[-1] > 3.0:  
                  fxs.append(x)
                  
        miny, maxy = area.bounds[1], area.bounds[3]
        lines = [LineString([(x, miny-10), (x, maxy+10)]) for x in fxs]
             
        if not lines: return [area]
        
        current_cells = [area]
        for line in lines:
            next_cells = []
            for cell in current_cells:
                collection = split(cell, line)
                if hasattr(collection, 'geoms'):
                    next_cells.extend(collection.geoms)
                else:
                    next_cells.append(collection)
            current_cells = next_cells

        cells = []
        for geom in current_cells:
             if geom.area > 5.0: # Remover celdas residuales muy pequeñas
                  cells.append(geom)
        
        return cells

    def safe_transit(self, p1, p2, area_context=None):
        area = area_context if area_context is not None else self.operable_area
        if not area or area.is_empty: return [p1, p2]
        
        line = LineString([p1, p2])
        if line.within(area.buffer(0.01)):
            return [p1, p2]
            
        import heapq
        
        all_points = [p1, p2]
        if area.geom_type == 'Polygon':
            all_points.extend(list(area.exterior.coords))
            for interior in area.interiors:
                all_points.extend(list(interior.coords))
        elif area.geom_type == 'MultiPolygon':
            for poly in area.geoms:
                all_points.extend(list(poly.exterior.coords))
                for interior in poly.interiors:
                    all_points.extend(list(interior.coords))
                    
        pts = [p1, p2]
        for p in all_points[2:]:
            duplicate = False
            for up in pts:
                if np.linalg.norm(np.array(p) - np.array(up)) < 0.1:
                    duplicate = True
                    break
            if not duplicate:
                pts.append(p)
                
        graph = {i: [] for i in range(len(pts))}
        buffered_area = area.buffer(0.01)
        
        for i in range(len(pts)):
            for j in range(i+1, len(pts)):
                l = LineString([pts[i], pts[j]])
                if l.within(buffered_area):
                    d = np.linalg.norm(np.array(pts[i]) - np.array(pts[j]))
                    graph[i].append((j, d))
                    graph[j].append((i, d))
                    
        queue = [(0, 0, [])] 
        visited = set()
        
        while queue:
            dist, current, current_path = heapq.heappop(queue)
            
            if current == 1:
                final_path = [pts[idx] for idx in current_path + [1]]
                return [p1] + final_path[1:]
                
            if current in visited: continue
            visited.add(current)
            
            for neighbor, weight in graph[current]:
                if neighbor not in visited:
                    heapq.heappush(queue, (dist + weight, neighbor, current_path + [current]))
                    
        return [p1, p2]

    def calculate_vertical_grid_global(self):
        return self.calculate_vertical_grid(self.operable_area)

    def calculate_diagonal_method(self):
        area = self.operable_area
        if not area or area.is_empty: return [], 0, 0
        rotated_area = affinity.rotate(area, -45, origin='centroid')
        path_rot, d, t = self.calculate_grid_method(rotated_area)
        if not path_rot: return [], 0, 0
        path_line = LineString(path_rot)
        unrotated_line = affinity.rotate(path_line, 45, origin='centroid')
        path = list(unrotated_line.coords)
        return path, d, t

    def calculate_perimeter(self):
        area = self.operable_area
        if not area or area.is_empty: return [], 0, 0
        path = []
        if area.geom_type == 'Polygon':
            path.extend(list(area.exterior.coords))
        elif area.geom_type == 'MultiPolygon':
            for geom in area.geoms:
                path.extend(list(geom.exterior.coords))
        if not path: return [], 0, 0
        dist, t = self.compute_metrics(path)
        return path, dist, t

    def calculate_grid_method(self, area=None):
        area = area if area is not None else self.operable_area
        if not area or area.is_empty: return [], 0, 0
        minx, miny, maxx, maxy = area.bounds
        y = miny + SWEEP_WIDTH / 2.0
        
        path = []
        left_to_right = True
        
        while y <= maxy:
            line = LineString([(minx - 10, y), (maxx + 10, y)])
            intersection = area.intersection(line)
            
            if not intersection.is_empty:
                segments = []
                if intersection.geom_type == 'LineString':
                    segments.append(list(intersection.coords))
                elif intersection.geom_type in ('MultiLineString', 'GeometryCollection'):
                    for geom in getattr(intersection, 'geoms', [intersection]):
                        if geom.geom_type == 'LineString':
                            segments.append(list(geom.coords))
                        
                segments.sort(key=lambda s: s[0][0], reverse=not left_to_right)
                
                for seg in segments:
                    if not left_to_right:
                        seg.reverse()
                    
                    if path:
                        transit = self.safe_transit(path[-1], seg[0], area)
                        if len(transit) > 1:
                            path.extend(transit[1:])
                        else:
                            path.append(seg[0])
                        path.extend(seg[1:])
                    else:
                        path.extend(seg)
            
            y += SWEEP_WIDTH
            left_to_right = not left_to_right
            
        dist, t = self.compute_metrics(path)
        return path, dist, t

    def calculate_spiral_method(self):
        area = self.operable_area
        if not area or area.is_empty: return [], 0, 0
        path = []
        buffer_dist = -SWEEP_WIDTH / 2.0
        current_poly = area
        
        while not current_poly.is_empty and current_poly.area > 0:
             if current_poly.geom_type == 'Polygon':
                 path.extend(list(current_poly.exterior.coords))
             elif current_poly.geom_type == 'MultiPolygon':
                 for geom in current_poly.geoms:
                     path.extend(list(geom.exterior.coords))
             
             buffer_dist -= SWEEP_WIDTH
             current_poly = area.buffer(buffer_dist)
             
        dist, t = self.compute_metrics(path)
        # El método espiral produce más giros constantes en la realidad que la aproximación simple.
        return path, dist, t * 1.5 

    def calculate_subdiv_method(self, cells):
        if not cells: return [], 0, 0
        full_path = []
        total_dist = 0
        total_time = 0
        
        for cell in cells:
            path, d, t = self.calculate_vertical_grid(cell)
            if path:
                if full_path:
                     transit = self.safe_transit(full_path[-1], path[0])
                     if len(transit) > 1:
                         full_path.extend(transit[1:])
                     else:
                         full_path.append(path[0])
                     full_path.extend(path[1:])
                else:
                     full_path.extend(path)
                     
        if full_path:
            total_dist, total_time = self.compute_metrics(full_path)
        return full_path, total_dist, total_time

    def calculate_vertical_grid(self, area):
        if not area or area.is_empty: return [], 0, 0
        minx, miny, maxx, maxy = area.bounds
        x = minx + SWEEP_WIDTH / 2.0
        
        path = []
        bottom_to_top = True
        
        while x <= maxx:
            line = LineString([(x, miny - 10), (x, maxy + 10)])
            intersection = area.intersection(line)
            
            if not intersection.is_empty:
                segments = []
                if intersection.geom_type == 'LineString':
                    segments.append(list(intersection.coords))
                elif intersection.geom_type in ('MultiLineString', 'GeometryCollection'):
                    for geom in getattr(intersection, 'geoms', [intersection]):
                         if geom.geom_type == 'LineString':
                             segments.append(list(geom.coords))
                        
                segments.sort(key=lambda s: s[0][1], reverse=not bottom_to_top)
                
                for seg in segments:
                    if not bottom_to_top: seg.reverse()
                    
                    if path:
                        transit = self.safe_transit(path[-1], seg[0])
                        if len(transit) > 1:
                            path.extend(transit[1:])
                        else:
                            path.append(seg[0])
                        path.extend(seg[1:])
                    else:
                        path.extend(seg)
            
            x += SWEEP_WIDTH
            bottom_to_top = not bottom_to_top
            
        dist, t = self.compute_metrics(path)
        return path, dist, t

if __name__ == '__main__':
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())
