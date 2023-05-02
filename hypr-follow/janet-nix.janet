(use sh)
(import spork/json)

(print "reading lockfile")

(with [lockfile (file/open "lockfile.jdn")]
  (def packages (eval-string (file/read lockfile :all)))
  (def sources @[])
  (each pack packages
    (def url (pack :url))
    (def rev (pack :tag))
    (->> ($< nix-prefetch-git ,url --rev ,rev --quiet)
         (json/decode)
         (array/push sources)))
  (with [jsonout (file/open "deps.json" :w)]
   (:write jsonout (json/encode sources))))
