(use sh)
(import spork/json)

(defn mkev [event value]
  {:event event
   :value value})

(defn collect-by [key coll]
  (reduce
    (fn [acc x]
      (let [k (x key)]
        (set (acc k) x)
        acc))
    (table/new (length coll)) coll))

(defn take-while-index [fun coll]
  (var i 0)
  (while (and (< i (length coll))
              (fun (get coll i)))
    (set i (inc i)))
  i)

(defn if= [tag value pat]
  ~(if (drop (cmt (-> ,tag) ,|(= $ value))) ,pat))

(def hyprmsg
  (peg/compile
    ~{:event (<- (some :w) :event)
      :text '(to "\n")
      :windowtitle (/ (* '(to ",") "," :text)
                      ,(fn [app title] {:app app :title title}))
      :monitor (/ (* '(to ",") "," '(number (some :d)))
                  ,(fn [name id _] {:name name :workspace id}))
      :value (+ ,(if= :event "activewindow" :windowtitle)
                ,(if= :event "workspace" '(number (some :d)))
                ,(if= :event "createworkspace" :text)
                ,(if= :event "destroyworkspace" :text)
                ,(if= :event "focusedmon" :monitor)
                :text)
      :main (some (/ (* :event ">>" :value "\n") ,mkev))}))


(def Monitor
  @{:set-active-workspace
    (fn [self ws]
      (set (self :active-workspace) ws))

    :add-workspace
    (fn [self ws]
      # We need to insert the workspace into the correct position.)})
      (array/insert
        (self :workspaces)
        (or (-?> (take-while-index |(<= (get $ :id) (ws :id)) (self :workspaces)))
            0)
        ws))

    :remove-workspace
    (fn [self ws]
      (-?>> (find-index |(= (get $ :name)) ws (self :workspaces))
           (array/remove (self :workspaces))))})

(defn make-monitor [monitor]
  (table/setproto
    @{:name (monitor "name")
      :id (monitor "id")
      :active-workspace ((monitor "activeWorkspace") "id")
      :focused (monitor "focused")
      :workspaces @[]}
    Monitor))

(defn make-workspace [workspace]
  @{:id (workspace "id")
    :name (workspace "name")
    :monitor (workspace "monitor")
    :windows (workspace "windows")})

(defn get-workspaces []
  (->> ($< hyprctl workspaces -j)
      (json/decode)
      (map make-workspace)
      (collect-by :name)))

(defn main [&]
  (def monitors
    (->> ($< hyprctl monitors -j)
        (json/decode)
        (map make-monitor)
        # (map (fn [w] (set (w "workspaces") @[]) w))
        (collect-by :name)))

  (->> ($< hyprctl workspaces -j)
      (json/decode)
      (map (fn [ws]
            (let [monitor (get monitors (get ws "monitor"))]
              (:add-workspace monitor (make-workspace ws))))))

  # TODO: create-workspace, activewindow, etc... should not be hard
  (print (json/encode monitors))
  (flush)
  (with
    [conn (net/connect
            :unix
            (string "/tmp/hypr/"
                    (os/getenv "HYPRLAND_INSTANCE_SIGNATURE")
                    "/.socket2.sock"))]

    (var monitor (find |(get $ :focused) monitors))

    (while true
      (do
        (def res (:read conn 4096))

        (each event (peg/match hyprmsg res)
          # (pp event)
          (case (event :event)
            "workspace" (:set-active-workspace monitor (event :value))
            # TODO: Update :focused on monitors
            "focusedmon" (set monitor (find |(= (get $ :name) ((event :value) :name)) monitors))
            "createworkspace"
            (let [workspace ((get-workspaces) (event :value))]
              (:add-workspace
                (monitors (workspace :monitor))
                workspace))
            "destroyworkspace" (:remove-workspace monitor (event :value))))
            
        (print (json/encode monitors))
        (flush)))))
