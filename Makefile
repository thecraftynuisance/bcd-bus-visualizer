###
### Reusable Makefile for Crafty Computer boards
### 
### © 2026 The Crafty Nuisance
###
### You may redistribute and modify this documentation and make products using
### it under the terms of the CERN-OHL-P v2 ([https:/cern.ch/cern-ohl]).  This
### documentation is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY,
### INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A
### PARTICULAR PURPOSE. Please see the CERN-OHL-P v2
### (https://ohwr.org/cern_ohl_p_v2.txt) for applicable conditions.


### Project-specific variables
VERSION := v1.0
PROJECT_NAME := bcd-bus-visualizer
IMAGE_WIDTH := 600
IMAGE_HEIGHT := 900

### Layers, will likely only need to be changed to change the number of layers
FRONT_LAYERS := F.Cu F.Fab F.Mask F.Paste F.Silkscreen
BACK_LAYERS := B.Cu B.Fab B.Mask B.Paste B.Silkscreen
MFG_LAYERS := F.Cu F.Mask F.Paste F.Silkscreen B.Cu B.Mask B.Paste B.Silkscreen Edge.Cuts

### Everything after this point should work across projects if they use the same directory structure
KICAD_DIR := ./hardware/kicad
GERBERS_DIR := ./production/gerbers
DOCS_DIR := ./documentation
IMAGES_DIR := $(DOCS_DIR)/images

PCB_FILE := $(KICAD_DIR)/$(PROJECT_NAME).kicad_pcb
SCH_FILE := $(KICAD_DIR)/$(PROJECT_NAME).kicad_sch

FRONT_PDF := $(addprefix $(DOCS_DIR)/$(PROJECT_NAME)-, $(addsuffix .pdf, $(subst .,_,$(FRONT_LAYERS))))
BACK_PDF := $(addprefix $(DOCS_DIR)/$(PROJECT_NAME)-, $(addsuffix .pdf, $(subst .,_,$(BACK_LAYERS))))
LAYER_GERBERS := $(addprefix $(GERBERS_DIR)/$(PROJECT_NAME)-, $(addsuffix .gbr, $(subst .,_,$(MFG_LAYERS))))
ALL_GERBERS := $(LAYER_GERBERS) $(GERBERS_DIR)/$(PROJECT_NAME)-job.gbrjob
DRILL := $(GERBERS_DIR)/$(PROJECT_NAME)-NPTH.drl $(GERBERS_DIR)/$(PROJECT_NAME)-PTH.drl
MFG_ZIP := $(GERBERS_DIR)/$(PROJECT_NAME)-$(VERSION).zip

COMMA := ,
MFG_LAYERS_COMMA := $(subst $(EMPTY) ,$(COMMA),$(MFG_LAYERS))

all: pdf image bom gerbers drill zip
clean:
	rm -f $(FRONT_PDF) $(BACK_PDF) $(DOCS_DIR)/$(PROJECT_NAME)-schematics.pdf $(IMAGES_DIR)/$(PROJECT_NAME)_front.png $(IMAGES_DIR)/$(PROJECT_NAME)_back.png $(DOCS_DIR)/$(PROJECT_NAME)-bom.csv $(ALL_GERBERS) $(DRILL) $(MFG_ZIP)

pdf: frontpdf backpdf $(DOCS_DIR)/$(PROJECT_NAME)-schematics.pdf
frontpdf: $(FRONT_PDF)
backpdf: $(BACK_PDF)
image: $(IMAGES_DIR)/$(PROJECT_NAME)_front.png $(IMAGES_DIR)/$(PROJECT_NAME)_back.png
bom: $(DOCS_DIR)/$(PROJECT_NAME)-bom.csv
gerbers: $(ALL_GERBERS)
drill: $(DRILL)
zip: $(MFG_ZIP)

# Front PDF
$(DOCS_DIR)/$(PROJECT_NAME)-F_%.pdf: $(PCB_FILE)
	@mkdir -p $(DOCS_DIR)
	kicad-cli pcb export pdf -o "$@" "$<" -l "F.$*,Edge.Cuts" --black-and-white --include-border-title >/dev/null

# Back PDF (mirrored)
$(DOCS_DIR)/$(PROJECT_NAME)-B_%.pdf: $(PCB_FILE)
	@mkdir -p $(DOCS_DIR)
	kicad-cli pcb export pdf -o "$@" "$<" -l "B.$*,Edge.Cuts" --black-and-white --include-border-title --mirror >/dev/null

# Front image
$(IMAGES_DIR)/$(PROJECT_NAME)_front.png: $(PCB_FILE)
	@mkdir -p $(IMAGES_DIR)
	kicad-cli pcb render -o "$@" "$<" --quality basic -w $(IMAGE_WIDTH) -h $(IMAGE_HEIGHT) --background transparent >/dev/null

# Back image (weird combination of flags prevents it from being lit only on the top side that you can't see in a bottom view)
$(IMAGES_DIR)/$(PROJECT_NAME)_back.png: $(PCB_FILE)
	@mkdir -p $(IMAGES_DIR)
	kicad-cli pcb render -o "$@" "$<" --quality basic -w $(IMAGE_WIDTH) -h $(IMAGE_HEIGHT) --preset Back_Render --side bottom --background transparent >/dev/null


# BOM
$(DOCS_DIR)/$(PROJECT_NAME)-bom.csv: $(SCH_FILE)
	@mkdir -p $(DOCS_DIR)
	kicad-cli sch export bom -o "$@" "$<" >/dev/null

# Schematics PDF
$(DOCS_DIR)/$(PROJECT_NAME)-schematics.pdf: $(SCH_FILE)
	@mkdir -p $(DOCS_DIR)
	kicad-cli sch export pdf -o "$@" "$<" >/dev/null

# Per-layer Gerbers
$(ALL_GERBERS)&: $(PCB_FILE)
	@mkdir -p $(GERBERS_DIR)
	kicad-cli pcb export gerbers -o "$(GERBERS_DIR)" "$<" -l "$(MFG_LAYERS_COMMA)" --no-protel-ext >/dev/null

# Drill files
$(DRILL)&: $(PCB_FILE)
	@mkdir -p $(GERBERS_DIR)
	kicad-cli pcb export drill -o "$(GERBERS_DIR)" "$<" --excellon-separate-th >/dev/null

# Zip file with all Gerbers
$(MFG_ZIP): $(DRILL) $(ALL_GERBERS)
	@rm -f "$@"
	cd $(GERBERS_DIR) && zip -q $(notdir $@) $(notdir $^)

.PHONY: all clean pdf frontpdf backpdf image bom gerbers drill zip
