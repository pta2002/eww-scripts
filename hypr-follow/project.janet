(declare-project
  :name "hypr-follow"
  :dependencies ["spork" "sh"])

(declare-executable
  :name "hypr-follow"
  :entry "hypr-follow.janet"
  :install true)
