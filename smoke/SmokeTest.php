<?php

class SmokeTest extends \PHPUnit\Framework\TestCase {
	public function testBootstrapLoaded(): void {
		$this->assertTrue(class_exists('OC'));
	}
}
