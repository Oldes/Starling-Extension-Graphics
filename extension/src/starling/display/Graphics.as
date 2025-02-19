package starling.display
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.geom.Matrix;
	
	import starling.display.graphics.Fill;
	import starling.display.graphics.NGon;
	import starling.display.graphics.Plane;
	import starling.display.graphics.Stroke;
	import starling.display.materials.IMaterial;
	import starling.display.shaders.fragment.TextureFragmentShader;
	import starling.display.shaders.fragment.TextureVertexColorFragmentShader;
	import starling.display.util.CurveUtil;
	import starling.textures.Texture;

	public class Graphics
	{
		// Shared texture fragment shader used across all graphics drawn via graphics API.
		private static var textureFragmentShader	:TextureFragmentShader = new TextureFragmentShader();
		public static const BEZIER_ERROR:Number = 0.75;
		private static const DEG_TO_RAD:Number = Math.PI / 180;
		
		private var _currentX				:Number;
		private var _currentY				:Number;
		private var _currentStroke			:Stroke;
		private var _currentFill			:Fill;
		
		private var _fillColor				:uint;
		private var _fillAlpha				:Number;
		private var _strokeThickness		:Number
		private var _strokeColor			:uint;
		private var _strokeAlpha			:Number;
		private var _strokeTexture			:Texture;
		private var _strokeMaterial			:IMaterial;
		
		private var _container				:DisplayObjectContainer;
		
		public function Graphics(displayObjectContainer:DisplayObjectContainer)
		{
			_container = displayObjectContainer;
		}
		
		public function clear():void
		{
			while ( _container.numChildren > 0 )
			{
				var child:DisplayObject = _container.getChildAt(0);
				child.dispose();
				_container.removeChildAt(0);
			}
			_currentX = NaN;
			_currentY = NaN;
		}
		
		public function beginFill(color:uint, alpha:Number = 1.0):void
		{
			_fillColor = color;
			_fillAlpha = alpha;
			
			_currentFill = new Fill();
			_container.addChild(_currentFill);
		}
		
		/**
		 * Warning - this function will create a fresh texture for each bitmap.
		 * It is reccomended to use beginTextureFill to ensure texture re-use.
		 */
		public function beginBitmapFill(bitmap:BitmapData, uvMatrix:Matrix = null):void
		{
			_fillColor = 0xFFFFFF;
			_fillAlpha = 1;
			
			_currentFill = new Fill();
			_currentFill.material.fragmentShader = textureFragmentShader;
			_currentFill.material.textures[0] = Texture.fromBitmapData( bitmap, false );
			
			if ( uvMatrix )
			{
				_currentFill.uvMatrix = uvMatrix;
			}
			
			_container.addChild(_currentFill);
		}
		
		public function beginTextureFill( texture:Texture, uvMatrix:Matrix = null ):void
		{
			_fillColor = 0xFFFFFF;
			_fillAlpha = 1;
			
			_currentFill = new Fill();
			_currentFill.material.fragmentShader = textureFragmentShader;
			_currentFill.material.textures[0] = texture;
			
			if ( uvMatrix ) {
				_currentFill.uvMatrix = uvMatrix;
			}
			
			_container.addChild(_currentFill);
		}
		
		public function beginMaterialFill( material:IMaterial, uvMatrix:Matrix = null ):void
		{
			_fillColor = 0xFFFFFF;
			_fillAlpha = 1;
			
			_currentFill = new Fill();
			_currentFill.material = material;
			
			if ( uvMatrix ) {
				_currentFill.uvMatrix = uvMatrix;
			}
			
			_container.addChild(_currentFill);
		}
		
		public function endFill():void
		{
			if ( _currentFill && _currentFill.numVertices < 3 ) {
				_container.removeChild(_currentFill);
			}
			
			_fillColor 	= NaN;
			_fillAlpha 	= NaN;
			_currentFill= null;
		}
		
		public function drawCircle(x:Number, y:Number, radius:Number):void
		{
			drawEllipse(x, y, radius, radius);
		}
		
		public function drawEllipse(x:Number, y:Number, width:Number, height:Number):void
		{
			// Pretty crude, but works.
			var numSides:int = Math.sqrt(width*width+height*height) * 0.5;
			
			// Use an NGon primitive instead of fill to bypass triangulation.
			var cachedFill:Fill = _currentFill;
			if ( _currentFill )
			{
				var nGon:NGon = new NGon(width, numSides);
				nGon.x = x;
				nGon.y = y;
				nGon.scaleY = height/width;
				nGon.material = _currentFill.material;
				
				var uvMatrix:Matrix = _currentFill.uvMatrix.clone();
				uvMatrix.invert();
				if ( nGon.material.textures.length > 0 )
				{
					uvMatrix.scale( 1/_currentFill.material.textures[0].width, (1/_currentFill.material.textures[0].height) * nGon.scaleY );
					//uvMatrix.translate( -
				}
				nGon.uvMatrix = uvMatrix;
				_container.addChild(nGon);
				_currentFill = null;
			}
			
			
			// Draw the stroke
			if ( isNaN(_strokeThickness) == false )
			{
				var anglePerSide:Number = (Math.PI * 2) / numSides;
				var a:Number = Math.cos(anglePerSide);
				var b:Number = Math.sin(anglePerSide);
				var s:Number = 0.0;
				var c:Number = 1.0;
				
				for ( var i:int = 0; i <= numSides; i++ )
				{
					var x:Number = s * width;
					var y:Number = -c * height;
					if ( i == 0 )
					{
						moveTo(x,y);
					}
					else
					{
						lineTo(x,y);
					}
					
					const ns:Number = b*c + a*s;
					const nc:Number = a*c - b*s;
					c = nc;
					s = ns;
				}
			}
			
			_currentFill = cachedFill;
		}
		
		
		public function drawRect(x:Number, y:Number, width:Number, height:Number):void
		{
			// Use a Plane primitive instead of fill to side-step triangulation.
			var cachedFill:Fill = _currentFill;
			if ( _currentFill )
			{
				var plane:Plane = new Plane(width, height);
				plane.material = _currentFill.material;
				
				var uvMatrix:Matrix = _currentFill.uvMatrix.clone();
				uvMatrix.invert();
				if ( plane.material.textures.length > 0 )
				{
					uvMatrix.scale( 1/_currentFill.material.textures[0].width, 1/_currentFill.material.textures[0].height );
				}
				plane.uvMatrix = uvMatrix;
				plane.x = x;
				plane.y = y;
				_container.addChild(plane);
				_currentFill = null;
			}
			moveTo(x, y);
			lineTo(x + width, y);
			lineTo(x + width, y + height);
			lineTo(x, y + height);
			lineTo(x, y);
			_currentFill = cachedFill;
		}
		
		public function lineStyle(thickness:Number = NaN, color:uint = 0, alpha:Number = 1.0):void
		{
			_strokeThickness		= thickness;
			_strokeColor			= color;
			_strokeAlpha			= alpha;
			_strokeTexture 			= null;
			_strokeMaterial				= null;
		}
		
		public function lineTexture(thickness:Number = NaN, texture:Texture = null):void
		{
			_strokeThickness		= thickness;
			_strokeColor			= 0xFFFFFF;
			_strokeAlpha			= 1;
			_strokeTexture 			= texture;
			_strokeMaterial			= null;
		}
		
		public function lineMaterial(thickness:Number = NaN, material:IMaterial = null):void
		{
			_strokeThickness		= thickness;
			_strokeColor			= 0xFFFFFF;
			_strokeAlpha			= 1;
			_strokeTexture			= null;
			_strokeMaterial			= material;
		}
		
		public function moveTo(x:Number, y:Number):void
		{
			if ( _strokeTexture ) 
			{
				beginTextureStroke();
			} 
			else if ( _strokeMaterial )
			{
				beginMaterialStroke();
			}
			else if ( _strokeThickness > 0 )
			{  	
				beginStroke();
			}
			
			if ( _currentStroke )
			{
				_currentStroke.addVertex( x, y, _strokeThickness, _strokeColor, _strokeAlpha, _strokeColor, _strokeAlpha );
			}
			
			if (_currentFill) 
			{
				_currentFill.addVertex(x, y, _fillColor, _fillAlpha );
			}
			
			_currentX = x;
			_currentY = y;
		}
		
		public function lineTo(x:Number, y:Number):void
		{
			if (!_currentStroke && _strokeThickness > 0) 
			{
				if (_strokeTexture) 
				{
					beginTextureStroke();
				}
				else if ( _strokeMaterial )
				{
					beginMaterialStroke();
				}
				else
				{
					beginStroke();
				}
			}
			
			if ( isNaN(_currentX) )
			{
				moveTo(0,0);
			}
			
			if ( _currentStroke )
			{
				_currentStroke.addVertex( x, y, _strokeThickness, _strokeColor, _strokeAlpha, _strokeColor, _strokeAlpha );
			}
			
			if (_currentFill) 
			{
				_currentFill.addVertex(x, y, _fillColor, _fillAlpha );
			}
			_currentX = x;
			_currentY = y;
		}
		
		public function curveTo(cx:Number, cy:Number, a2x:Number, a2y:Number, error:Number = BEZIER_ERROR ):void
		{
			var startX:Number = _currentX;
			var startY:Number = _currentY;
			
			if ( isNaN(startX) )
			{
				startX = 0;
				startY = 0;
			}
			
			var points:Vector.<Number> = CurveUtil.quadraticCurve(startX, startY, cx, cy, a2x, a2y, error);
			
			var L:int = points.length;
			for ( var i:int = 0; i < L; i+=2 )
			{
				var x:Number = points[i];
				var y:Number = points[i+1];
				
				if ( i == 0 && isNaN(_currentX) )
				{
					moveTo( x, y );
				}
				else
				{
					lineTo( x, y );
				}
			}
			
			_currentX = a2x;
			_currentY = a2y;
		}
		
		public function cubicCurveTo(c1x:Number, c1y:Number, c2x:Number, c2y:Number, a2x:Number, a2y:Number, error:Number = BEZIER_ERROR ):void
		{
			var startX:Number = _currentX;
			var startY:Number = _currentY;
			
			if ( isNaN(startX) )
			{
				startX = 0;
				startY = 0;
			}
			
			var points:Vector.<Number> = CurveUtil.cubicCurve(startX, startY, c1x, c1y, c2x, c2y, a2x, a2y, error);
			
			var L:int = points.length;
			for ( var i:int = 0; i < L; i+=2 )
			{
				var x:Number = points[i];
				var y:Number = points[i+1];
				
				if ( i == 0 && isNaN(_currentX) )
				{
					moveTo( x, y );
				}
				else
				{
					lineTo( x, y );
				}
			}
			_currentX = a2x;
			_currentY = a2y;
		}
		
		////////////////////////////////////////
		// PRIVATE
		////////////////////////////////////////
		
		private function beginStroke():void
		{
			if ( _currentStroke && _currentStroke.numVertices < 2 ) {
				_container.removeChild(_currentStroke);
			}
			
			_currentStroke = new Stroke();
			_container.addChild(_currentStroke);
		}
		
		private function beginTextureStroke():void
		{
			if ( _currentStroke && _currentStroke.numVertices < 2 ) {
				_container.removeChild(_currentStroke);
			}
			
			_currentStroke = new Stroke();
			_currentStroke.material.fragmentShader = textureFragmentShader;
			_currentStroke.material.textures[0] = _strokeTexture;
			_container.addChild(_currentStroke);
		}
		
		private function beginMaterialStroke():void
		{
			if ( _currentStroke && _currentStroke.numVertices < 2 ) 
			{
				_container.removeChild(_currentStroke);
			}
			
			_currentStroke = new Stroke();
			_currentStroke.material = _strokeMaterial;
			_container.addChild(_currentStroke);
		}
		
		private function deg2rad (deg:Number):Number {
			return deg * Math.PI / 180;
		}
	}
}