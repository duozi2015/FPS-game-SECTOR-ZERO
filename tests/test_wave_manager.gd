extends GdUnitTestSuite

## T14 [RED] WaveManager 波次组合验收（design.md §9）
## 组合规则：total = 3 + wave*2；brutes = wave/3（int 除法）；
## shooters 从第 2 波起 = min(wave-1, int(total*0.35))；其余为 grunt

func test_wave1_composition() -> void:
	var c := WaveManager.compose_wave(1)
	assert_int(c["grunt"]).is_equal(5)
	assert_int(c["shooter"]).is_equal(0)
	assert_int(c["brute"]).is_equal(0)


func test_wave2_introduces_shooter() -> void:
	var c := WaveManager.compose_wave(2)
	assert_int(c["grunt"]).is_equal(6)
	assert_int(c["shooter"]).is_equal(1)
	assert_int(c["brute"]).is_equal(0)


func test_wave3_introduces_brute() -> void:
	var c := WaveManager.compose_wave(3)
	assert_int(c["total"]).is_equal(9)
	assert_int(c["brute"]).is_equal(1)
	assert_int(c["shooter"]).is_equal(2)
	assert_int(c["grunt"]).is_equal(6)


func test_wave6_composition() -> void:
	var c := WaveManager.compose_wave(6)
	assert_int(c["total"]).is_equal(15)
	assert_int(c["brute"]).is_equal(2)
	assert_int(c["shooter"]).is_equal(5)  # min(5, int(15*0.35)=5) = 5
	assert_int(c["grunt"]).is_equal(8)


func test_composition_sums_to_total() -> void:
	for wave in range(1, 13):
		var c := WaveManager.compose_wave(wave)
		assert_int(c["grunt"] + c["shooter"] + c["brute"]).override_failure_message(
			"wave %d 组合数不等于总数" % wave).is_equal(c["total"])


func test_shooter_ratio_capped() -> void:
	# 高波次射手占比不超过 int(total*0.35)
	var c := WaveManager.compose_wave(12)
	assert_int(c["shooter"]).is_less_equal(int(c["total"] * 0.35))
