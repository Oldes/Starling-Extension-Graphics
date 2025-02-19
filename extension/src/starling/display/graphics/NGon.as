/*

	A fairly versatile primitive capable of representing circles, fans, hoops, and arcs.

	Contains a great sin/cos trick learned from Iñigo Quílez's site
	http://www.iquilezles.org/www/articles/sincos/sincos.htm

*/

package starling.display.graphics
{
	import flash.geom.Matrix;
	import flash.geom.Point;
	
	import starling.core.RenderSupport;
	import starling.core.Starling;

	public class NGon extends Graphic
	{
		private const DEGREES_TO_RADIANS	:Number = Math.PI / 180;
		private const VERTEX_STRIDE		:int = 9;
		
		private var _radius			:Number;
		private var _innerRadius	:Number;
		private var _startAngle		:Number;
		private var _endAngle		:Number;
		private var _numSides		:int;
		private var _uvMatrix		:Matrix;
		private var isInvalid		:Boolean;
		
		public function NGon( radius:Number = 100, numSides:int = 10, innerRadius:Number = 0, startAngle:Number = 0, endAngle:Number = 360 )
		{
			this.radius = radius;
			this.numSides = numSides;
			this.innerRadius = innerRadius;
			this.startAngle = startAngle;
			this.endAngle = endAngle;
		}
		
		public function get endAngle():Number
		{
			return _endAngle;
		}

		public function set endAngle(value:Number):void
		{
			_endAngle = value;
			isInvalid = true;
		}

		public function get startAngle():Number
		{
			return _startAngle;
		}

		public function set startAngle(value:Number):void
		{
			_startAngle = value;
			isInvalid = true;
		}

		public function get radius():Number
		{
			return _radius;
		}
		
		public function set radius(value:Number):void
		{
			value = value < 0 ? 0 : value;
			_radius = value;
			var maxRadius:Number = Math.max(_radius, _innerRadius);
			minBounds.x = minBounds.y = -maxRadius;
			maxBounds.x = minBounds.y = maxRadius;
			isInvalid = true;
		}
		
		public function get innerRadius():Number
		{
			return _innerRadius;
		}

		public function set innerRadius(value:Number):void
		{
			value = value < 0 ? 0 : value;
			_innerRadius = value;
			var maxRadius:Number = Math.max(_radius, _innerRadius);
			minBounds.x = minBounds.y = -maxRadius;
			maxBounds.x = minBounds.y = maxRadius;
			isInvalid = true;
		}

		public function get numSides():int
		{
			return _numSides;
		}

		public function set numSides(value:int):void
		{
			value = value < 3 ? 3 : value;
			_numSides = value;
			isInvalid = true;
		}
		
		public function get uvMatrix():Matrix
		{
			return _uvMatrix;
		}
		
		public function set uvMatrix(value:Matrix):void
		{
			_uvMatrix = value;
			isInvalid = true;
		}
		
		override public function render( renderSupport:RenderSupport, alpha:Number ):void
		{
			if ( isInvalid )
			{
				validate();
				isInvalid = false;
			}
			
			super.render( renderSupport, alpha );
		}
		
		private function validate():void
		{
			// Manipulate the input startAngle and endAngle values
			// into sa and ea. sa will always end up less than
			// ea, and ea-sa is the shortest clockwise distance
			// between them.
			var sa:Number = _startAngle;
			var ea:Number = _endAngle;
			var sSign:int = sa < 0 ? -1 : 1;
			var eSign:int = ea < 0 ? -1 : 1;
			sa *= sSign;
			ea *= eSign;
			ea = ea % 360;
			ea *= eSign;
			sa = sa % 360;
			if ( ea < sa )
			{
				ea += 360;
			}
			sa *= sSign * DEGREES_TO_RADIANS;
			ea *= DEGREES_TO_RADIANS;
			if ( ea - sa > Math.PI*2 )
			{
				ea -= Math.PI*2;
			}
			
			// Manipulate innerRadius and outRadius in r and ir.
			// ir will always be less than r.
			var ir:Number = _innerRadius < _radius ? _innerRadius : _radius;
			var r:Number = _radius > _innerRadius ? _radius : _innerRadius;
			
			// Based upon the input values, choose from
			// 4 primitive types. Each more complex than the next.
			var vertices:Vector.<Number> = new Vector.<Number>();
			var indices:Vector.<uint> = new Vector.<uint>();
			var isSegment:Boolean = sa != 0 || ea != 0;
			if ( ir == 0 && !isSegment )
			{
				buildSimpleNGon(r, _numSides, vertices, indices, _uvMatrix);
			}
			else if ( ir != 0 && !isSegment )
			{
				buildHoop(ir, r, _numSides, vertices, indices, _uvMatrix);
			}
			else if ( ir == 0 )
			{
				buildFan(r, sa, ea, _numSides, vertices, indices, _uvMatrix);
			}
			else
			{
				buildArc( ir, r, sa, ea, _numSides, vertices, indices, _uvMatrix);
			}
			
			// (Re)build vertex and index buffers.
			if ( vertexBuffer )
			{
				vertexBuffer.dispose();
				indexBuffer.dispose();
				vertexBuffer = null;
			}
			var numVertices:int = vertices.length / VERTEX_STRIDE;
			vertexBuffer = Starling.context.createVertexBuffer( numVertices, VERTEX_STRIDE );
			vertexBuffer.uploadFromVector( vertices, 0, numVertices )
			indexBuffer = Starling.context.createIndexBuffer( indices.length );
			indexBuffer.uploadFromVector( indices, 0, indices.length );
		}
		
		private static function buildSimpleNGon( radius:Number, numSides:int, vertices:Vector.<Number>, indices:Vector.<uint>, uvMatrix:Matrix = null ):void
		{
			var numVertices:int = 0;
			var uv:Point = new Point(0.5,0.5);
			if ( uvMatrix )
			{
				uv = uvMatrix.transformPoint(uv);
			}
			vertices.push( 0, 0, 0, 1, 1, 1, 1, uv.x, uv.y );
			numVertices++;
			
			var anglePerSide:Number = (Math.PI * 2) / numSides;
			var a:Number = Math.cos(anglePerSide);
			var b:Number = Math.sin(anglePerSide);
			var s:Number = 0.0;
			var c:Number = 1.0;
			
			for ( var i:int = 0; i < numSides; i++ )
			{
				var x:Number = s * radius;
				var y:Number = -c * radius;
				uv.x = x/(radius*2)+0.5;
				uv.y = y/(radius*2)+0.5;
				if ( uvMatrix )
				{
					uv = uvMatrix.transformPoint(uv);
				}
				vertices.push( x, y, 0, 1, 1, 1, 1, uv.x, uv.y );
				numVertices++;
				indices.push( 0, numVertices-1, i == numSides-1 ? 1 : numVertices );
				
				const ns:Number = b*c + a*s;
				const nc:Number = a*c - b*s;
				c = nc;
				s = ns;
			}
		}
		
		private static function buildHoop( innerRadius:Number, radius:Number, numSides:int, vertices:Vector.<Number>, indices:Vector.<uint>, uvMatrix:Matrix = null ):void
		{
			var numVertices:int = 0;
			
			var anglePerSide:Number = (Math.PI * 2) / numSides;
			var a:Number = Math.cos(anglePerSide);
			var b:Number = Math.sin(anglePerSide);
			var s:Number = 0.0;
			var c:Number = 1.0;
			var uv:Point = new Point();
			
			for ( var i:int = 0; i < numSides; i++ )
			{
				var x:Number = s * radius;
				var y:Number = -c * radius;
				uv.x = x/(radius*2)+0.5;
				uv.y = y/(radius*2)+0.5;
				if ( uvMatrix )
				{
					uv = uvMatrix.transformPoint(uv);
				}
				
				vertices.push( x, y, 0, 1, 1, 1, 1, uv.x, uv.y );
				numVertices++;
				
				x = s * innerRadius;
				y = -c * innerRadius;
				uv.x = x/(radius*2)+0.5;
				uv.y = y/(radius*2)+0.5;
				if ( uvMatrix )
				{
					uv = uvMatrix.transformPoint(uv);
				}
				
				vertices.push( x, y, 0, 1, 1, 1, 1, uv.x, uv.y );
				numVertices++;
			
				if ( i == numSides-1 )
				{
					indices.push( numVertices-2, numVertices-1, 0, 0, numVertices-1, 1 );
				}
				else
				{
					indices.push( numVertices-2, numVertices-1, numVertices, numVertices, numVertices-1, numVertices+1 );
				}
				
				const ns:Number = b*c + a*s;
				const nc:Number = a*c - b*s;
				c = nc;
				s = ns;
			}
		}
		
		private static function buildFan( radius:Number, startAngle:Number, endAngle:Number, numSides:int, vertices:Vector.<Number>, indices:Vector.<uint>, uvMatrix:Matrix = null ):void
		{
			var numVertices:int = 0;
			var uv:Point = new Point();
			uv.x = x;
			uv.y = y;
			if ( uvMatrix )
			{
				uv = uvMatrix.transformPoint(uv);
			}
			
			vertices.push( 0, 0, 0, 1, 1, 1, 1, uv.x, uv.y );
			numVertices++;
			
			var radiansPerDivision:Number = (Math.PI * 2) / numSides;
			var startRadians:Number = (startAngle / radiansPerDivision);
			startRadians = startRadians < 0 ? -Math.ceil(-startRadians) : int(startRadians);
			startRadians *= radiansPerDivision;
			for ( var i:int = 0; i <= numSides+1; i++ )
			{
				var radians:Number = startRadians + i*radiansPerDivision;
				var nextRadians:Number = radians + radiansPerDivision;
				if ( nextRadians < startAngle ) continue;
				
				var x:Number = Math.sin( radians ) * radius;
				var y:Number = -Math.cos( radians ) * radius;
				var prevRadians:Number = radians-radiansPerDivision;
				
				var t:Number
				if ( radians < startAngle && nextRadians > startAngle )
				{
					var nextX:Number = Math.sin(nextRadians) * radius;
					var nextY:Number = -Math.cos(nextRadians) * radius;
					t = (startAngle-radians) / radiansPerDivision;
					x += t * (nextX-x);
					y += t * (nextY-y);
				}
				else if ( radians > endAngle && prevRadians < endAngle )
				{
					var prevX:Number = Math.sin(prevRadians) * radius;
					var prevY:Number = -Math.cos(prevRadians) * radius;
					
					t = (endAngle-prevRadians) / radiansPerDivision;
					x = prevX + t * (x-prevX);
					y = prevY + t * (y-prevY);
				}
				
				uv.x = x/(radius*2)+0.5;
				uv.y = y/(radius*2)+0.5;
				if ( uvMatrix )
				{
					uv = uvMatrix.transformPoint(uv);
				}
				
				vertices.push( x, y, 0, 1, 1, 1, 1, uv.x, uv.y );
				numVertices++;
				
				if ( vertices.length > 2*9 )
				{
					indices.push( 0, numVertices-2, numVertices-1 );
				}
				
				if ( radians >= endAngle )
				{
					break;
				}
			}
		}
		
		private static function buildArc( innerRadius:Number, radius:Number, startAngle:Number, endAngle:Number, numSides:int, vertices:Vector.<Number>, indices:Vector.<uint>, uvMatrix:Matrix = null ):void
		{
			var nv:int = 0;
			var uv:Point = new Point();
			var radiansPerDivision:Number = (Math.PI * 2) / numSides;
			var startRadians:Number = (startAngle / radiansPerDivision);
			startRadians = startRadians < 0 ? -Math.ceil(-startRadians) : int(startRadians);
			startRadians *= radiansPerDivision;
			for ( var i:int = 0; i <= numSides+1; i++ )
			{
				var angle:Number = startRadians + i*radiansPerDivision;
				var nextAngle:Number = angle + radiansPerDivision;
				if ( nextAngle < startAngle ) continue;
				
				var sin:Number = Math.sin(angle);
				var cos:Number = Math.cos(angle);
				
				var x:Number = sin * radius;
				var y:Number = -cos * radius;
				var x2:Number = sin * innerRadius;
				var y2:Number = -cos * innerRadius;
				
				var prevAngle:Number = angle-radiansPerDivision;
				
				var t:Number
				if ( angle < startAngle && nextAngle > startAngle )
				{
					sin = Math.sin(nextAngle);
					cos = Math.cos(nextAngle);
					var nextX:Number = sin * radius;
					var nextY:Number = -cos * radius;
					var nextX2:Number = sin * innerRadius;
					var nextY2:Number = -cos * innerRadius;
					t = (startAngle-angle) / radiansPerDivision;
					x += t * (nextX-x);
					y += t * (nextY-y);
					x2 += t * (nextX2-x2);
					y2 += t * (nextY2-y2);
				}
				else if ( angle > endAngle && prevAngle < endAngle )
				{
					sin = Math.sin(prevAngle);
					cos = Math.cos(prevAngle);
					var prevX:Number = sin * radius;
					var prevY:Number = -cos * radius;
					var prevX2:Number = sin * innerRadius;
					var prevY2:Number = -cos * innerRadius;
					
					t = (endAngle-prevAngle) / radiansPerDivision;
					x = prevX + t * (x-prevX);
					y = prevY + t * (y-prevY);
					x2 = prevX2 + t * (x2-prevX2);
					y2 = prevY2 + t * (y2-prevY2);
				}
				
				uv.x = x/(radius*2)+0.5;
				uv.y = y/(radius*2)+0.5;
				if ( uvMatrix )
				{
					uv = uvMatrix.transformPoint(uv);
				}
				
				vertices.push( x, y, 0, 1, 1, 1, 1, uv.x, uv.y );
				nv++;
				
				uv.x = x2/(radius*2)+0.5;
				uv.y = y2/(radius*2)+0.5;
				if ( uvMatrix )
				{
					uv = uvMatrix.transformPoint(uv);
				}
				
				vertices.push( x2, y2, 0, 1, 1, 1, 1, uv.x, uv.y );
				nv++;
				
				if ( vertices.length > 3*9 )
				{
					indices.push( nv-1, nv-2, nv-3, nv-3, nv-2, nv-4 );
				}
				
				if ( angle >= endAngle )
				{
					break;
				}
			}
		}
	}
}