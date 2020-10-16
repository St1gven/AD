echo router1 router2  | tr " " "\n" | xargs -P2 -I {} vagrant up {}
echo dc1 dc2 ws1 | tr " " "\n" | xargs -P5 -I {} vagrant up {}