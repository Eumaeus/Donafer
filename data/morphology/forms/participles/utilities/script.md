TEST_GRK="παιδεύω"; FN="$TEST_GRK.txt"; echo "template#template.txt\nlemma#the verb '$TEST_GRK'\n\n" > $FN

^(([0-9]+)-([0-9])_([^_]+)_([^_]+)_([^_]+))\.txt

echo "template#template_verb_\3_\4_\5_\6.txt\\nlemma#the verb “\$1”\\n\\n" > verb_\$1/\1_\$1.txt;

