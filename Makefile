


DART=/bin/dart 

name=M68K_Homage


init:
	$(DART) pub get
	$(DART) pub add build_runner build_web_compilers --dev
	${DART} pub global activate webdev


update_packages:
	$(DART) pub get

# make_dummy_web_app:
# 	$(DART) create -t web XXX

serve:
	webdev serve --verbose --debug web


serve_release:
	webdev serve --verbose --release web

build_release:
	webdev build --verbose --release --output web:build
	rm -f $(name).zip
	python3 tools/pack_data.py
	cd build/packed; zip ../../$(name).zip $(name).txt $(name).html


prod_serve:
	python3 -m http.server -d build
